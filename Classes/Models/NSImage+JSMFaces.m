//
//  NSImage+JSMFaces.m
//  Faces
//
//  Created by Jonathon Mah on 2008-07-08.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import "NSImage+JSMFaces.h"
#import "NSBitmapImageRep+JSMFaces.h"


static CvHaarClassifierCascade *frontalFaceCascade;
static NSSize maxSizeOfImageForDetection = {640.0f, 640.0f};


@implementation NSImage (JSMFaces)

- (NSArray *)detectFaces;
{
	if (!frontalFaceCascade)
	{
		NSString *cascadePath = [[NSBundle mainBundle] pathForResource:@"haarcascade_frontalface_alt" ofType:@"xml"];
		//NSString *cascadePath = [[NSBundle mainBundle] pathForResource:@"haarcascade_profileface" ofType:@"xml"];
		frontalFaceCascade = (CvHaarClassifierCascade *)cvLoad([cascadePath fileSystemRepresentation], 0, 0, 0);
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
		NSImage *smallerImage = [[NSImage alloc] initWithSize:newPixelSize];
		
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
	
	// Do the face detection
    CvMemStorage *storage = cvCreateMemStorage(0);
	CvSeq *facesSeq = cvHaarDetectObjects(iplImage, frontalFaceCascade, storage, 1.1, 3, CV_HAAR_DO_CANNY_PRUNING, cvSize(0, 0));
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
