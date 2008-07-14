//
//  JSMController.m
//  Faces
//
//  Created by Jonathon Mah on 2008-07-08.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import "JSMController.h"
#import "RMMessage.h"


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
#warning Generate APp Support path
		NSString *haarCascadeStoragePath = [@"~/Library/Caches/com.jonathonmah.haarcascadeobjects.plist" stringByExpandingTildeInPath];
		NSURL *haarCascadeStorageURL = [NSURL fileURLWithPath:haarCascadeStoragePath];
		_haarCascadeController = [[JSMHaarCascadeController alloc] initWithStorageURL:haarCascadeStorageURL];
		_haarCascadeController.delegate = self;
		
		_sourceItems = [NSArray array];
		_faces = [NSMutableArray array];
		_faceExtractionQueue = [[NSOperationQueue alloc] init];
		[_faceExtractionQueue setMaxConcurrentOperationCount:[[NSProcessInfo processInfo] activeProcessorCount]];
	}
	return self;
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
		[sourceItem setObject:[image objectForKey:@"ImagePath"] forKey:@"path"];
		[sourceItem setObject:[NSDate dateWithTimeIntervalSinceReferenceDate:[[image objectForKey:@"DateAsTimerInterval"] doubleValue]] forKey:@"date"];
		[sourceItem setObject:[NSDate dateWithTimeIntervalSinceReferenceDate:[[image objectForKey:@"ModDateAsTimerInterval"] doubleValue]] forKey:@"modificationDate"];
		[sourceItem setObject:[image objectForKey:@"Caption"] forKey:@"title"];
		
		[sourceItems addObject:sourceItem];
	}
	return sourceItems;
}


- (void)setSourceItems:(NSArray *)items;
{
	_sourceItems = [items copy];
	
	NSMutableDictionary *modDates = [NSMutableDictionary dictionaryWithCapacity:[_sourceItems count]];
	for (NSDictionary *item in _sourceItems)
		[modDates setObject:[item objectForKey:@"modificationDate"]
					 forKey:[item objectForKey:@"path"]];
	_sourceItemModificationDatesByPath = modDates;
}


- (void)startFaceDetection;
{
	[_faceExtractionQueue cancelAllOperations];
	[_faceExtractionQueue waitUntilAllOperationsAreFinished];
	
	NSSortDescriptor *dateDescending = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:NO];
	NSArray *sortedItems = [self.sourceItems sortedArrayUsingDescriptors:[NSArray arrayWithObject:dateDescending]];
	[_haarCascadeController beginDetectionOfImagesAtPaths:[sortedItems valueForKey:@"path"] withCascadeNamed:@"haarcascade_frontalface_alt"];
}


- (void)haarCascadeController:(JSMHaarCascadeController *)controller
			   didDetectRects:(NSRectArray)rects
						count:(NSUInteger)rectCount
			withCascadeAtPath:(NSString *)cascadePath
					 forImage:(NSImage *)image
					   atPath:(NSString *)path;
{
	if (rectCount > 0)
		[_faceExtractionQueue addOperation:[[JSMFaceExtractionOperation alloc] initWithImage:image
																					   rects:rects
																					   count:rectCount
																					delegate:self]];
}


- (NSDate *)haarCascadeController:(JSMHaarCascadeController *)controller
	 modificationDateOfFileAtPath:(NSString *)path;
{
	return [_sourceItemModificationDatesByPath objectForKey:path];
}


- (void)addFaces:(NSArray *)faces;
{
	[[self mutableArrayValueForKey:@"faces"] addObjectsFromArray:faces];
}


@end

