//
//  NSImage+JSMHaarCascadeObjectDetection.m
//  Faces
//
//  Created by Jonathon Mah on 2008-07-08.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import "NSImage+JSMHaarCascadeObjectDetection.h"
#import "NSBitmapImageRep+JSMHaarCascadeObjectDetection.h"


NSString *JSMHaarCascadeFileExtension = @"xml";

static NSMutableDictionary *cascades;
static NSSize maxSizeOfImageForDetection = {640.0f, 640.0f};


@implementation NSImage (JSMHaarCascadeObjectDetection)


+ (void)load;
{
	cascades = [NSMutableDictionary dictionary];
}


- (NSRectArray)detectObjectsWithHaarCascadeNamed:(NSString *)cascadeName count:(NSUInteger *)outCount;
{
	NSString *path = [[NSBundle mainBundle] pathForResource:cascadeName ofType:JSMHaarCascadeFileExtension];
	if (!path)
		[NSException raise:NSInvalidArgumentException format:@"Unable to find cascade %@.%@ in main bundle", cascadeName, JSMHaarCascadeFileExtension];
	return [self detectObjectsWithHaarCascadeAtPath:path count:outCount];
}


- (NSRectArray)detectObjectsWithHaarCascadeAtPath:(NSString *)cascadePath count:(NSUInteger *)outCount;
{
	NSCondition *cascadeLock;
	NSMutableArray *availableCascades;
	
	@synchronized(cascades)
	{
		NSDictionary *cascadeInfo = [cascades objectForKey:cascadePath];
		if (!cascadeInfo)
		{
			// Load and cache cascade
			NSUInteger cascadeCount = [[NSProcessInfo processInfo] processorCount];
			NSMutableArray *cascadeInstances = [NSMutableArray arrayWithCapacity:cascadeCount];
			
			CvHaarClassifierCascade *cascade = (CvHaarClassifierCascade *)cvLoad([cascadePath fileSystemRepresentation], 0, 0, 0);
			if (!cascade)
				[NSException raise:NSInvalidArgumentException format:@"Unable to load cascade at path %@", cascadePath];
			[cascadeInstances addObject:[NSValue valueWithPointer:cascade]];
			while ([cascadeInstances count] < cascadeCount)
				[cascadeInstances addObject:[NSValue valueWithPointer:cvClone(cascade)]];
			
			cascadeInfo = [NSDictionary dictionaryWithObjectsAndKeys:[[NSCondition alloc] init], @"lock",
																	 cascadeInstances, @"availableCascades",
																	 nil];
			[cascades setObject:cascadeInfo forKey:cascadePath];
		}
		
		cascadeLock = [cascadeInfo objectForKey:@"lock"];
		availableCascades = [cascadeInfo objectForKey:@"availableCascades"];
	}
	
	// Get a cascade
	[cascadeLock lock];
	while ([availableCascades count] == 0)
		[cascadeLock wait];
	NSValue *cascadeWrapper = [availableCascades lastObject];
	[availableCascades removeLastObject];
	[cascadeLock unlock];
	
	NSRectArray objectRects = [self detectObjectsWithHaarCascade:[cascadeWrapper pointerValue] count:outCount];
	
	// Mark the cascade as available
	[cascadeLock lock];
	[availableCascades addObject:cascadeWrapper];
	[cascadeLock signal];
	[cascadeLock unlock];
	
	return objectRects;
}


- (NSRectArray)detectObjectsWithHaarCascade:(CvHaarClassifierCascade *)cascade count:(NSUInteger *)outCount;
{
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
	NSAssert(iplImage, @"Unable to get IPL image");
	
	// Do the face detection
    CvMemStorage *storage = cvCreateMemStorage(0);
	NSAssert(storage, @"Unable to create a memory storage area for cascade detection");
	CvSeq *facesSeq = cvHaarDetectObjects(iplImage, cascade, storage, 1.1, 3, CV_HAAR_DO_CANNY_PRUNING, cvSize(0, 0));
	
	// Convert and scale face areas
	NSUInteger objectCount = (facesSeq ? facesSeq->total : 0);
	*outCount = objectCount;
	NSRectArray rects = NULL;
	if (objectCount > 0)
	{
		rects = NSAllocateCollectable(objectCount * sizeof(NSRect), 0);
		NSAssert(rects, @"Unable to allocate collectable memory for object rects");
	}
	for (NSUInteger i = 0; i < objectCount; i++)
	{
		CvRect *cvRect = (CvRect*)cvGetSeqElem(facesSeq, i);
		NSRect *rect = &rects[i];
		*rect = NSMakeRect(cvRect->x, 0.0f, cvRect->width, cvRect->height);
		rect->origin.y = iplImage->height - cvRect->y - cvRect->height;
		
		rect->origin.x /= scaleFactor * resolution.width;
		rect->origin.y /= scaleFactor * resolution.height;
		rect->size.width /= scaleFactor * resolution.width;
		rect->size.height /= scaleFactor * resolution.height;
	}
	
	cvReleaseMemStorage(&storage);
	cvReleaseImage(&iplImage);
	
	return rects;
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
