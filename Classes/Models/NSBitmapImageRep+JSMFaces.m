//
//  NSBitmapImageRep+JSMFaces.m
//  Faces
//
//  Created by Jonathon Mah on 2008-07-08.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import "NSBitmapImageRep+JSMFaces.h"


@implementation NSBitmapImageRep (JSMFaces)


- (IplImage *)copyIplImage;
{
	NSSize pixelSize = NSMakeSize(self.pixelsWide, self.pixelsHigh);
	NSInteger channelCount = [self samplesPerPixel];
	IplImage *iplImage = cvCreateImage(cvSize(pixelSize.width, pixelSize.height), IPL_DEPTH_8U, channelCount);
	
	NSUInteger pixelData[channelCount];
	for (NSUInteger y = 0; y < pixelSize.height; y++)
	{
		NSUInteger rowOffset = y * ((NSUInteger)pixelSize.width * channelCount);
		for (NSUInteger x = 0; x < pixelSize.width; x++)
		{
			NSUInteger columnOffset = x * channelCount;
			[self getPixel:pixelData atX:x y:y];
			for (NSInteger i = 0; i < channelCount; i++)
			{
				iplImage->imageData[rowOffset + columnOffset + i] = pixelData[i];
			}
		}
	}
	
	return iplImage;
}


@end
