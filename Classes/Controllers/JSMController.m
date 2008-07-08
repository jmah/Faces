//
//  JSMController.m
//  Faces
//
//  Created by Jonathon Mah on 2008-07-08.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import "JSMController.h"
#import "NSImage+JSMFaces.h"


@implementation JSMController

@synthesize image = _image;

- (void)setImage:(NSImage *)image;
{
	_image = [image copy];
	[self extractFaces];
}


- (void)extractFaces;
{
	if (!self.image)
		return;
	CGFloat outsetFactor = 0.2f;
	NSRect imageRect = NSMakeRect(0.0f, 0.0f, self.image.size.width, self.image.size.height);
	for (NSValue *wrappedRect in [self.image detectFaces])
	{
		NSRect rect = [wrappedRect rectValue];
		NSRect expandedRect = NSInsetRect(rect, -outsetFactor * NSWidth(rect), -outsetFactor * NSHeight(rect));
		NSRect clippedRect = NSIntersectionRect(expandedRect, imageRect);
		if (NSEqualSizes(clippedRect.size, NSZeroSize))
			continue;
		
		NSImage *face = [[NSImage alloc] initWithSize:clippedRect.size];
		[face lockFocus];
		[self.image drawInRect:NSMakeRect(0.0f, 0.0f, NSWidth(clippedRect), NSHeight(clippedRect))
					  fromRect:clippedRect
					 operation:NSCompositeSourceOver
					  fraction:1.0f];
		[face unlockFocus];
		
		[facesBucketController addObject:[NSDictionary dictionaryWithObject:face forKey:@"image"]];
	}
}


+ (NSSet *)keyPathsForValuesAffectingImageWithHighlightedFaces;
{
	return [NSSet setWithObject:@"image"];
}


- (NSImage *)imageWithHighlightedFaces;
{
	if (!self.image)
		return nil;
	
	NSImage *highlighted = [[NSImage alloc] initWithSize:[self.image size]];
	
	[highlighted lockFocus];
	[self.image compositeToPoint:NSZeroPoint operation:NSCompositeSourceOver];
	
	[[[NSColor greenColor] colorWithAlphaComponent:0.4f] set];
	for (NSValue *wrappedRect in [self.image detectFaces])
		[NSBezierPath fillRect:[wrappedRect rectValue]];
	[highlighted unlockFocus];
	
	return highlighted;
}


@end
