//
//  LLFaceReplacementOperation.m
//  Faces
//
//  Created by Jonathon Mah on 2008-07-09.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import "LLFaceReplacementOperation.h"
#import "LLController.h"
#import "RMMessage.h"
#import "NSImage+JSMHaarCascadeObjectDetection.h"


@implementation LLFaceReplacementOperation


- (id)initWithSourceItem:(NSMutableDictionary *)sourceItem controller:(LLController *)controller;
{
	if ((self = [super init]))
	{
		_sourceItem = sourceItem;
		_controller = controller;
		_minFaceCount = 1;
	}
	return self;
}


@synthesize sourceItem = _sourceItem;
@synthesize controller = _controller;
@synthesize minFaceCount = _minFaceCount;


- (CGFloat)rectOutsetFactor;
{
	return 0.3f;
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
	
	NSUInteger faceCount;
	NSRectArray faceRects = [image detectObjectsWithHaarCascadeNamed:@"haarcascade_frontalface_alt" count:&faceCount];
	if (faceCount < self.minFaceCount)
		return;
	if (self.isCancelled)
		return;
	
	NSArray *luchadorFaces = self.controller.maskImages;
	
	NSImageRep *rep = [image bestRepresentationForDevice:nil];
	NSSize pointSize = [image size];
	NSSize pixelSize = NSMakeSize(rep.pixelsWide, rep.pixelsHigh);
	NSSize resolution = NSMakeSize(pixelSize.width / pointSize.width, pixelSize.height / pointSize.height);
	
	[image lockFocus];
	for (NSUInteger i = 0; i < faceCount; i++)
	{
		NSRect rect = faceRects[i];
		rect.origin.x *= resolution.width;
		rect.origin.y *= resolution.height;
		rect.size.width *= resolution.width;
		rect.size.height *= resolution.height;
		
		NSRect expandedRect = NSInsetRect(rect, -self.rectOutsetFactor * NSWidth(rect), -self.rectOutsetFactor * NSHeight(rect));
		
		// Calculate rect for face image
		NSImage *luchadorFace = [luchadorFaces objectAtIndex:(random() % [luchadorFaces count])];
		NSSize faceSourceSize = [luchadorFace size];
		CGFloat faceRatio = faceSourceSize.width / faceSourceSize.height;
		NSRect faceDestRect;
		faceDestRect.size = NSMakeSize(MIN(NSWidth(expandedRect), NSHeight(expandedRect) * faceRatio),
									   MIN(NSHeight(expandedRect), NSWidth(expandedRect) / faceRatio));
		faceDestRect.origin = NSMakePoint(NSMidX(rect) - NSWidth(faceDestRect) / 2.0f, NSMidY(rect) - NSHeight(faceDestRect) / 2.0f);
		
		[luchadorFace drawInRect:faceDestRect
						fromRect:NSMakeRect(0.0f, 0.0f, faceSourceSize.width, faceSourceSize.height)
					   operation:NSCompositeSourceOver
						fraction:1.0f];
		
		if (self.isCancelled)
			break;
	}
	[image unlockFocus];
	
	if (self.isCancelled)
		return;
	
	[self.controller performOnMainThread:MSG(addLuchadorImage:image forItemWithUUID:[self.sourceItem objectForKey:@"uuid"]) waitUntilDone:NO];
}


@end
