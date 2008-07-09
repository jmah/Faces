//
//  JSMController.m
//  Faces
//
//  Created by Jonathon Mah on 2008-07-08.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import "JSMController.h"
#import "RMMessage.h"
#import "JSMFaceDetectionOperation.h"


@interface JSMController ()

@property(readwrite, copy) NSArray *sourceItems;

- (void)loadIPhotoLibraryThreaded;
- (NSArray *)sourceItemsFromIPhotoLibrary;
- (void)startFaceDetection;

@end


@implementation JSMController


- (id)init;
{
	if ((self = [super init]))
	{
		_sourceItems = [NSArray array];
		_faces = [NSMutableArray array];
		_faceDetectionQueue = [[NSOperationQueue alloc] init];
		[_faceDetectionQueue setMaxConcurrentOperationCount:[[NSProcessInfo processInfo] activeProcessorCount]];
	}
	return self;
}


- (void)awakeFromNib;
{
	[progressBar startAnimation:self];
}


@synthesize sourceItems = _sourceItems;
@synthesize faces = _faces;


- (void)applicationWillFinishLaunching:(NSNotification *)notification;
{
	[self detachNewThreadSelector:MSG(loadIPhotoLibraryThreaded)];
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
	[progressBar setDoubleValue:0];
	[progressBar setMaxValue:[self.sourceItems count]];
	[progressBar setIndeterminate:NO];
	NSSortDescriptor *dateDescending = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:NO];
	for (NSMutableDictionary *sourceItem in [self.sourceItems sortedArrayUsingDescriptors:[NSArray arrayWithObject:dateDescending]])
		[_faceDetectionQueue addOperation:[[JSMFaceDetectionOperation alloc] initWithSourceItem:sourceItem
																					 controller:self]];
}


- (void)addFaces:(NSArray *)faces;
{
	[[self mutableArrayValueForKey:@"faces"] addObjectsFromArray:faces];
}


- (void)updateProgressBar;
{
	[progressBar setDoubleValue:[progressBar maxValue] - [[_faceDetectionQueue operations] count]];
}


@end

