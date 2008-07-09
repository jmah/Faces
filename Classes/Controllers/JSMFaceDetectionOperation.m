//
//  JSMFaceDetectionOperation.m
//  Faces
//
//  Created by Jonathon Mah on 2008-07-09.
//  Copyright 2008 Playhaus. All rights reserved.
//

#import "JSMFaceDetectionOperation.h"
#import "JSMController.h"
#import "RMMessage.h"
#import "NSImage+JSMFaces.h"



@implementation JSMFaceDetectionOperation


- (id)initWithSourceItem:(NSMutableDictionary *)sourceItem controller:(JSMController *)controller;
{
	if ((self = [super init]))
	{
		_sourceItem = sourceItem;
		_controller = controller;
	}
	return self;
}


@synthesize sourceItem = _sourceItem;
@synthesize controller = _controller;


- (CGFloat)rectOutsetFactor;
{
	return 0.2f;
}


- (void)main;
{
	NSData *data = [NSData dataWithContentsOfFile:[self.sourceItem objectForKey:@"path"]
										  options:NSUncachedRead
											error:NULL];
	NSImage *image = [[NSImage alloc] initWithData:data];
	if (!image)
		return;
	if (self.isCancelled)
		return;
	
	NSMutableArray *faces = [NSMutableArray array];
	NSRect imageRect = NSMakeRect(0.0f, 0.0f, image.size.width, image.size.height);
	for (NSValue *wrappedRect in [image detectFaces])
	{
		NSRect rect = [wrappedRect rectValue];
		NSRect expandedRect = NSInsetRect(rect, -self.rectOutsetFactor * NSWidth(rect), -self.rectOutsetFactor * NSHeight(rect));
		NSRect clippedRect = NSIntersectionRect(expandedRect, imageRect);
		if (NSEqualSizes(clippedRect.size, NSZeroSize))
			continue;
		
		NSImage *face = [[NSImage alloc] initWithSize:clippedRect.size];
		[face lockFocus];
		[image drawInRect:NSMakeRect(0.0f, 0.0f, NSWidth(clippedRect), NSHeight(clippedRect))
				 fromRect:clippedRect
				operation:NSCompositeSourceOver
				 fraction:1.0f];
		[face unlockFocus];
		
		[faces addObject:[NSDictionary dictionaryWithObjectsAndKeys:
						  face, @"image",
						  [self.sourceItem objectForKey:@"uuid"], @"uuid",
						  wrappedRect, @"rect",
						  nil]];
		if (self.isCancelled)
			return;
	}
	
	if (self.isCancelled)
		return;
	
	[self.controller performOnMainThread:MSG(addFaces:faces) waitUntilDone:NO];
	[self.controller performOnMainThread:MSG(updateProgressBar) waitUntilDone:NO];
}


@end
