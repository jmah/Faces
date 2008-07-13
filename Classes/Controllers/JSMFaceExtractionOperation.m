//
//  JSMFaceDetectionOperation.m
//  Faces
//
//  Created by Jonathon Mah on 2008-07-09.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import "JSMFaceExtractionOperation.h"
#import "JSMController.h"
#import "RMMessage.h"
#import "NSImage+JSMHaarCascadeObjectDetection.h"



@implementation JSMFaceExtractionOperation


- (id)initWithImage:(NSImage *)image rects:(NSRectArray)rects count:(NSUInteger)rectCount delegate:(id)delegate;
{
	if ((self = [super init]))
	{
		_image = image;
		_rects = rects;
		_rectCount = rectCount;
		_delegate = delegate;
	}
	return self;
}


- (CGFloat)rectOutsetFactor;
{
	return 0.2f;
}


- (void)main;
{
	NSRect imageRect = NSMakeRect(0.0f, 0.0f, _image.size.width, _image.size.height);
	NSMutableArray *faces = [NSMutableArray arrayWithCapacity:_rectCount];
	for (NSUInteger i = 0; i < _rectCount; i++)
	{
		NSRect rect = _rects[i];
		NSRect expandedRect = NSInsetRect(rect, -self.rectOutsetFactor * NSWidth(rect), -self.rectOutsetFactor * NSHeight(rect));
		NSRect clippedRect = NSIntersectionRect(expandedRect, imageRect);
		if (NSEqualSizes(clippedRect.size, NSZeroSize))
			continue;
		
		NSImage *face = [[NSImage alloc] initWithSize:clippedRect.size];
		[face lockFocus];
		[_image drawInRect:NSMakeRect(0.0f, 0.0f, NSWidth(clippedRect), NSHeight(clippedRect))
				  fromRect:clippedRect
				 operation:NSCompositeSourceOver
				  fraction:1.0f];
		[face unlockFocus];
		
		[faces addObject:[NSDictionary dictionaryWithObjectsAndKeys:
						  face, @"image",
						  [NSValue valueWithRect:rect], @"rect",
						  nil]];
		if (self.isCancelled)
			return;
	}
	
	if (self.isCancelled)
		return;
	
	[_delegate performOnMainThread:MSG(addFaces:faces) waitUntilDone:NO];
}


@end
