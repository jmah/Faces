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
#import "LLFaceReplacementOperation.h"


@interface LLController ()

@property(readwrite, copy) NSArray *sourceItems;

- (void)loadMaskImages;
- (void)loadIPhotoLibraryThreaded;
- (NSArray *)sourceItemsFromIPhotoLibrary;
- (void)startFaceDetection;
- (void)updateProgressSpinner;

@end


@implementation LLController


- (id)init;
{
	if ((self = [super init]))
	{
		_sourceItems = [NSArray array];
		_maskImages = [NSMutableArray array];
		_luchadorImages = [NSMutableArray array];
		_faceDetectionQueue = [[NSOperationQueue alloc] init];
		[_faceDetectionQueue setMaxConcurrentOperationCount:[[NSProcessInfo processInfo] activeProcessorCount]];
	}
	return self;
}


- (void)awakeFromNib;
{
	[NSTimer scheduledTimerWithTimeInterval:1.0f
									 target:self
								   selector:@selector(updateProgressSpinner)
								   userInfo:nil
									repeats:YES];
	[imageTransitionView bind:@"images" toObject:self withKeyPath:@"luchadorImages" options:nil];
}


@synthesize maskImages = _maskImages;
@synthesize sourceItems = _sourceItems;
@synthesize luchadorImages = _luchadorImages;


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
	[self performOnMainThread:MSG(setSourceItems:sourceItems) waitUntilDone:YES];
	[self performOnMainThread:MSG(startFaceDetection) waitUntilDone:NO];
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
		[sourceItem setObject:[image objectForKey:@"GUID"] forKey:@"uuid"];
		[sourceItem setObject:[image objectForKey:@"ImagePath"] forKey:@"path"];
		[sourceItem setObject:[NSDate dateWithTimeIntervalSinceReferenceDate:[[image objectForKey:@"DateAsTimerInterval"] doubleValue]] forKey:@"date"];
		[sourceItem setObject:[image objectForKey:@"Caption"] forKey:@"title"];
		
		[sourceItems addObject:sourceItem];
	}
	return sourceItems;
}


- (void)startFaceDetection;
{
	[_faceDetectionQueue cancelAllOperations];
	[_faceDetectionQueue waitUntilAllOperationsAreFinished];
	NSSortDescriptor *dateDescending = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:NO];
	for (NSMutableDictionary *sourceItem in [self.sourceItems sortedArrayUsingDescriptors:[NSArray arrayWithObject:dateDescending]])
	{
		LLFaceReplacementOperation *operation = [[LLFaceReplacementOperation alloc] initWithSourceItem:sourceItem
																							controller:self];
		operation.minFaceCount = 2;
		// Randomize things a bit
		[operation setQueuePriority:(random() % 30) - 15];
		[_faceDetectionQueue addOperation:operation];
	}
}


- (void)addLuchadorImage:(NSImage *)image forItemWithUUID:(NSString *)uuid;
{
	[[self mutableArrayValueForKey:@"luchadorImages"] addObject:image];
}


- (void)updateProgressSpinner;
{
	if ([[_faceDetectionQueue operations] count] == 0)
		[progressSpinner stopAnimation:self];
	else
		[progressSpinner startAnimation:self];
}


@end
