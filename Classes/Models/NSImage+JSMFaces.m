//
//  NSImage+JSMFaces.m
//  Faces
//
//  Created by Jonathon Mah on 2008-07-08.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import "NSImage+JSMFaces.h"
#import "NSBitmapImageRep+JSMFaces.h"


static id cascadeInitSemaphore;
static NSCondition *frontalFaceCascadeLock;
static NSMutableArray *availableFrontalFaceCascades;
static NSSize maxSizeOfImageForDetection = {640.0f, 640.0f};


@implementation NSImage (JSMFaces)

+ (void)load;
{
	cascadeInitSemaphore = [[NSObject alloc] init];
}


- (NSArray *)detectFaces;
{
	@synchronized(cascadeInitSemaphore)
	{
		if (!frontalFaceCascadeLock)
			frontalFaceCascadeLock = [[NSCondition alloc] init];
		
		if (!availableFrontalFaceCascades)
		{
			NSString *cascadePath = [[NSBundle mainBundle] pathForResource:@"haarcascade_frontalface_alt" ofType:@"xml"];
			if (!cascadePath)
			{
				NSLog(@"Unable to find cascade file in bundle");
				abort();
			}
			availableFrontalFaceCascades = [NSMutableArray array];
			CvHaarClassifierCascade *cascade = (CvHaarClassifierCascade *)cvLoad([cascadePath fileSystemRepresentation], 0, 0, 0);
			[availableFrontalFaceCascades addObject:[NSValue valueWithPointer:cascade]];
			
			NSUInteger cascadeCount = [[NSProcessInfo processInfo] processorCount];
			while ([availableFrontalFaceCascades count] < cascadeCount)
				[availableFrontalFaceCascades addObject:[NSValue valueWithPointer:cvClone(cascade)]];
		}
	}
	
	// Calculate the resolution in pixels per point so we can scale it back later
	NSImage *sourceImage = self;
	NSImageRep *rep = [self bestRepresentationForDevice:nil];
	NSSize pointSize = [self size];
	NSSize pixelSize = NSMakeSize(rep.pixelsWide, rep.pixelsHigh);
	NSSize resolution = NSMakeSize(pixelSize.width / pointSize.width, pixelSize.height / pointSize.height);
	
	// See if we should scale the image down
	CGFloat scaleFactor = 1.0f;
	if (!NSEqualSizes(maxSizeOfImageForDetection, NSZeroSize) && ((pixelSize.width > maxSizeOfImageForDetection.width) || (pixelSize.height > maxSizeOfImageForDetection.height)))
		scaleFactor = MIN(maxSizeOfImageForDetection.width / pixelSize.width, maxSizeOfImageForDetection.height / pixelSize.height);
	
	if (scaleFactor != 1.0f)
	{
		NSSize newPixelSize = NSMakeSize(pixelSize.width * scaleFactor, pixelSize.height * scaleFactor);
		NSImage *smallerImage = [[[NSImage alloc] initWithSize:newPixelSize] autorelease];
		
		NSRect sourceRect = NSZeroRect;
		sourceRect.size = self.size;
		NSRect destRect = NSZeroRect;
		destRect.size = newPixelSize;
		
		[smallerImage lockFocus];
		[self drawInRect:destRect fromRect:sourceRect operation:NSCompositeSourceOver fraction:1.0f];
		[smallerImage unlockFocus];
		
		sourceImage = smallerImage;
	}
	
	// Convert to IPL Image format
	IplImage *iplImage = [sourceImage copyIplImage];
	
	// Get a cascade
	[frontalFaceCascadeLock lock];
	while ([availableFrontalFaceCascades count] == 0)
		[frontalFaceCascadeLock wait];
	NSValue *cascadeWrapper = [availableFrontalFaceCascades lastObject];
	[availableFrontalFaceCascades removeLastObject];
	[frontalFaceCascadeLock unlock];
	
	CvHaarClassifierCascade *thisCascade = [cascadeWrapper pointerValue];
	
	// Do the face detection
    CvMemStorage *storage = cvCreateMemStorage(0);
	CvSeq *facesSeq = cvHaarDetectObjects(iplImage, thisCascade, storage, 1.1, 3, CV_HAAR_DO_CANNY_PRUNING, cvSize(0, 0));
	
	// Mark the cascade as available
	[frontalFaceCascadeLock lock];
	[availableFrontalFaceCascades addObject:cascadeWrapper];
	[frontalFaceCascadeLock signal];
	[frontalFaceCascadeLock unlock];
	
	NSUInteger faceCount = (facesSeq ? facesSeq->total : 0);
	
	// Convert and scale face areas
	NSMutableArray *faceRects = [NSMutableArray arrayWithCapacity:faceCount];
	for (NSUInteger i = 0; i < faceCount; i++)
	{
		CvRect *cvRect = (CvRect*)cvGetSeqElem(facesSeq, i);
		NSRect flippedRect = NSMakeRect(cvRect->x, 0.0f, cvRect->width, cvRect->height);
		flippedRect.origin.y = iplImage->height - cvRect->y - cvRect->height;
		
		flippedRect.origin.x /= scaleFactor * resolution.width;
		flippedRect.origin.y /= scaleFactor * resolution.height;
		flippedRect.size.width /= scaleFactor * resolution.width;
		flippedRect.size.height /= scaleFactor * resolution.height;
		[faceRects addObject:[NSValue valueWithRect:flippedRect]];
	}
	
	cvReleaseMemStorage(&storage);
	cvReleaseImage(&iplImage);
	
	return faceRects;
}


// Caller has responsibility to cvReleaseImage(&iplImage);
- (IplImage *)copyIplImage;
{
	NSImageRep *rep = [self bestRepresentationForDevice:nil];
	NSBitmapImageRep *bitmap = nil;
	if ([rep isKindOfClass:[NSBitmapImageRep class]])
		bitmap = (NSBitmapImageRep *)rep;
	else
		bitmap = [NSBitmapImageRep imageRepWithData:[self TIFFRepresentation]];
	return [bitmap copyIplImage];
}


@end
