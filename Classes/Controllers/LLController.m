//
//  LLController.m
//  Faces
//
//  Created by Jonathon Mah on 2008-07-09.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import "LLController.h"
#import "LLImageTransitionView.h"
#import "RMMessage.h"


static CGFloat faceRectOutsetFactor = 0.2f;


@interface LLController ()

- (void)loadMaskImages;
- (void)loadIPhotoLibraryThreaded;
- (NSArray *)sourceItemsFromIPhotoLibrary;
- (void)startFaceDetectionForSourceItems:(NSArray *)sourceItems;
- (void)updateProgressSpinner;

@end


@implementation LLController


- (id)init;
{
	if ((self = [super init]))
	{
		_maskImages = [NSMutableArray array];
		_luchadorImages = [NSMutableDictionary dictionary];
		
		NSString *cachesPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
		NSURL *haarCascadeStorageURL = [NSURL fileURLWithPath:[cachesPath stringByAppendingPathComponent:@"com.jonathonmah.haarcascadeobjects.plist"]];
		_haarCascadeController = [[JSMHaarCascadeController alloc] initWithStorageURL:haarCascadeStorageURL];
		_haarCascadeController.delegate = self;
	}
	return self;
}


- (void)awakeFromNib;
{
	[self updateProgressSpinner];
	[imageTransitionView bind:@"imageKeys" toObject:self withKeyPath:@"allImageKeys" options:nil];
}


- (void)updateProgressSpinner;
{
	if ([self.allImageKeys count] > 0)
		[progressSpinner stopAnimation:self];
	else
		[progressSpinner startAnimation:self];
}


@synthesize maskImages = _maskImages;


- (NSUInteger)minFaceCount;
{
	return 2;
}


- (NSArray *)allImageKeys;
{
	return [_luchadorImages allKeys];
}


- (void)applicationWillFinishLaunching:(NSNotification *)notification;
{
	[self loadMaskImages];
	[self detachNewThreadSelector:MSG(loadIPhotoLibraryThreaded)];
}


- (void)loadMaskImages;
{
	NSArray *masks = [[NSBundle mainBundle] pathsForResourcesOfType:@"png" inDirectory:@"Luchador Masks"];
	for (NSString *path in masks)
		[_maskImages addObject:[[NSImage alloc] initWithContentsOfFile:path]];
}


- (void)loadIPhotoLibraryThreaded;
{
	NSArray *sourceItems = [self sourceItemsFromIPhotoLibrary];
	[self performOnMainThread:MSG(startFaceDetectionForSourceItems:sourceItems) waitUntilDone:NO];
}


- (NSArray *)sourceItemsFromIPhotoLibrary;
{
	NSArray *albumDataPathComponents = [NSArray arrayWithObjects:NSHomeDirectory(), @"Pictures", @"iPhoto Library", @"AlbumData.xml", nil];
	NSString *albumDataPath = [NSString pathWithComponents:albumDataPathComponents];
	NSDictionary *albumData = [NSDictionary dictionaryWithContentsOfFile:albumDataPath];
	if (!albumData)
	{
		NSLog(@"Unable to load iPhoto album data");
		return [NSArray array];
	}
	
	NSArray *iPhotoImages = [[albumData objectForKey:@"Master Image List"] allValues];
	NSMutableArray *sourceItems = [NSMutableArray arrayWithCapacity:[iPhotoImages count]];
	for (NSDictionary *image in iPhotoImages)
	{
		NSMutableDictionary *sourceItem = [NSMutableDictionary dictionary];
		[sourceItem setObject:[image objectForKey:@"ImagePath"] forKey:@"path"];
		[sourceItem setObject:[NSDate dateWithTimeIntervalSinceReferenceDate:[[image objectForKey:@"DateAsTimerInterval"] doubleValue]] forKey:@"date"];
		[sourceItem setObject:[NSDate dateWithTimeIntervalSinceReferenceDate:[[image objectForKey:@"ModDateAsTimerInterval"] doubleValue]] forKey:@"modificationDate"];
		[sourceItem setObject:[image objectForKey:@"Caption"] forKey:@"title"];
		
		[sourceItems addObject:sourceItem];
	}
	return sourceItems;
}


- (void)startFaceDetectionForSourceItems:(NSArray *)sourceItems;
{
	NSMutableDictionary *modDates = [NSMutableDictionary dictionaryWithCapacity:[sourceItems count]];
	for (NSDictionary *item in sourceItems)
		[modDates setObject:[item objectForKey:@"modificationDate"]
					 forKey:[item objectForKey:@"path"]];
	_sourceItemModificationDatesByPath = modDates;
	
	NSSortDescriptor *dateDescending = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:NO];
	NSArray *sortedItems = [sourceItems sortedArrayUsingDescriptors:[NSArray arrayWithObject:dateDescending]];
	[_haarCascadeController beginDetectionOfImagesAtPaths:[sortedItems valueForKey:@"path"] withCascadeNamed:@"haarcascade_frontalface_alt"];
}


- (void)haarCascadeController:(JSMHaarCascadeController *)controller
			   didDetectRects:(NSRectArray)rects
						count:(NSUInteger)rectCount
			withCascadeAtPath:(NSString *)cascadePath
					 forImage:(NSImage *)image
					   atPath:(NSString *)path;
{
	if (rectCount > self.minFaceCount)
	{
		[self willChangeValueForKey:@"allImageKeys"];
		[_luchadorImages setObject:[NSData dataWithBytes:rects length:(rectCount * sizeof(NSRect))]
							forKey:path];
		[self didChangeValueForKey:@"allImageKeys"];
	}
}


- (NSDate *)haarCascadeController:(JSMHaarCascadeController *)controller
	 modificationDateOfFileAtPath:(NSString *)path;
{
	return [_sourceItemModificationDatesByPath objectForKey:path];
}


- (NSImage *)imageForKey:(NSString *)key;
{
	NSData *rectArrayData = [_luchadorImages objectForKey:key];
	NSRectArray faceRects = (NSRectArray)[rectArrayData bytes];
	NSUInteger faceCount = [rectArrayData length] / sizeof(NSRect);
	
	NSString *path = key;
	NSImage *sourceImage = [[NSImage alloc] initWithContentsOfFile:path];
	NSImageRep *rep = [sourceImage bestRepresentationForDevice:nil];
	if (!rep)
		return nil;
	
	NSImage *image = [[NSImage alloc] initWithSize:[sourceImage size]];
	
	[image lockFocus];
	[rep drawAtPoint:NSZeroPoint];
	
	for (NSUInteger i = 0; i < faceCount; i++)
	{
		NSRect rect = faceRects[i];
		NSRect expandedRect = NSInsetRect(rect, -faceRectOutsetFactor * NSWidth(rect), -faceRectOutsetFactor * NSHeight(rect));
		
		// Calculate rect for face image
		NSImage *luchadorFace = [self.maskImages objectAtIndex:(random() % [self.maskImages count])];
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
	}
	[image unlockFocus];
	return image;
}


@end
