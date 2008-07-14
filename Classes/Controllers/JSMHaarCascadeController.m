//
//  JSMHaarCascadeController.m
//  Faces
//
//  Created by Jonathon Mah on 2008-07-10.
//  Copyright 2008 Playhaus. All rights reserved.
//

#import "JSMHaarCascadeController.h"
#import "NSImage+JSMHaarCascadeObjectDetection.h"
#import <SSCrypto/SSCrypto.h>


static NSTimeInterval modificationDateEpsilon = 1.0;


@interface JSMHaarCascadeController ()

- (NSDate *)modificationDateOfFileAtPath:(NSString *)path;
- (void)applicationWillTerminate:(NSNotification *)notification;

@end


@implementation JSMHaarCascadeController


- (id)initWithStorageURL:(NSURL *)url;
{
	if  ((self = [super init]))
	{
		_storageURL = url;
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(applicationWillTerminate:)
													 name:NSApplicationWillTerminateNotification
												   object:NSApp];
		_detectionQueue = [[NSOperationQueue alloc] init];
		[_detectionQueue setMaxConcurrentOperationCount:[[NSProcessInfo processInfo] activeProcessorCount]];
		
		NSData *storedData = nil;
		if (_storageURL)
			storedData = [NSData dataWithContentsOfURL:_storageURL options:NSUncachedRead error:NULL];
		if (storedData)
			_detectionResults = [NSPropertyListSerialization propertyListFromData:storedData
																 mutabilityOption:NSPropertyListMutableContainersAndLeaves
																		   format:NULL
																 errorDescription:NULL];
		if (!_detectionResults)
			_detectionResults = [NSMutableDictionary dictionary];
		
	}
	return self;
}


@synthesize storageURL = _storageURL;
@synthesize delegate = _delegate;



- (void)beginDetectionOfImagesAtPaths:(NSArray *)paths withCascadeNamed:(NSString *)cascadeName;
{
	NSString *cascadePath = [[NSBundle mainBundle] pathForResource:cascadeName ofType:JSMHaarCascadeFileExtension];
	if (!cascadePath)
		[NSException raise:NSInvalidArgumentException format:@"Unable to find cascade %@.%@ in main bundle", cascadeName, JSMHaarCascadeFileExtension];
	NSData *cascadeData = [NSData dataWithContentsOfFile:cascadePath];
	NSString *cascadeHash = [[SSCrypto getSHA1ForData:cascadeData] hexval];
	
	for (NSString *path in paths)
	{
		NSArray *rectStrings = nil;
		
		NSDate *modificationDate = [self modificationDateOfFileAtPath:path];
		NSMutableDictionary *imageInfo = [_detectionResults objectForKey:path];
		if (imageInfo)
		{
			// Compare against an epsilon because (evidently) dates aren't stored exactly in plist format
			if ([modificationDate timeIntervalSinceDate:[imageInfo objectForKey:@"modificationDate"]] > modificationDateEpsilon)
			{
				// Data in cache has modification data older than the current image
				[_detectionResults removeObjectForKey:path];
				imageInfo = nil;
			}
			else
			{
				// Cache of detected rects is still valid
				NSMutableDictionary *cachedRectsByCascadeHash = [imageInfo objectForKey:@"rectsByCascadeHash"];
				rectStrings = [cachedRectsByCascadeHash objectForKey:cascadeHash];
			}
		}
		
		if (rectStrings)
		{
			//NSLog(@"Cache hit for: %@", path);
			NSRectArray rects = NSAllocateCollectable([rectStrings count] * sizeof(NSRect), 0);
			
			NSRect *currRect = rects;
			for (NSString *rectString in rectStrings)
				*currRect++ = NSRectFromString(rectString);
			
			if ([(id)self.delegate respondsToSelector:@selector(haarCascadeController:didDetectRects:count:withCascadeAtPath:forImage:atPath:)])
				[self.delegate haarCascadeController:self
									  didDetectRects:rects
											   count:[rectStrings count]
								   withCascadeAtPath:cascadePath
											forImage:[[NSImage alloc] initByReferencingFile:path]
											  atPath:path];
		}
		else
		{
			//NSLog(@"Cache miss for: %@", path);
			NSOperation *operation = [[JSMHaarCascadeDetectionOperation alloc] initWithImageAtPath:path
																			  withModificationDate:modificationDate
																				usingCascadeAtPath:cascadePath
																						  withHash:cascadeHash
																						  delegate:self];
			[_detectionQueue addOperation:operation];
		}
	}
}


- (void)haarCascadeDetectionOperationDidDetectRects:(NSRectArray)rects
											  count:(NSUInteger)rectCount
										   forImage:(NSImage *)image
											 atPath:(NSString *)imagePath
							   withModificationDate:(NSDate *)modificationDate
								 usingCascadeAtPath:(NSString *)cascadePath
										   withHash:(NSString *)cascadeHash;
{
	NSMutableDictionary *imageInfo = [_detectionResults objectForKey:imagePath];
	NSMutableDictionary *cachedRectsByCascadeHash = [imageInfo objectForKey:@"rectsByCascadeHash"];
	if (!imageInfo)
	{
		imageInfo = [NSMutableDictionary dictionary];
		cachedRectsByCascadeHash = [NSMutableDictionary dictionary];
		
		[imageInfo setObject:cachedRectsByCascadeHash forKey:@"rectsByCascadeHash"];
		[_detectionResults setObject:imageInfo forKey:imagePath];
	}
	
	[imageInfo setObject:modificationDate forKey:@"modificationDate"];
	
	NSMutableArray *rectStrings = [NSMutableArray arrayWithCapacity:rectCount];
	for (NSUInteger i = 0; i < rectCount; i++)
		[rectStrings addObject:NSStringFromRect(rects[i])];
	
	[cachedRectsByCascadeHash setObject:rectStrings forKey:cascadeHash];
	
	if ([(id)self.delegate respondsToSelector:@selector(haarCascadeController:didDetectRects:count:withCascadeAtPath:forImage:atPath:)])
		[self.delegate haarCascadeController:self
							  didDetectRects:rects
									   count:rectCount
						   withCascadeAtPath:cascadePath
									forImage:image
									  atPath:imagePath];
}


- (NSDate *)modificationDateOfFileAtPath:(NSString *)path;
{
	NSDate *date = nil;
	if ([(id)self.delegate respondsToSelector:@selector(haarCascadeController:modificationDateOfFileAtPath:)])
		date = [self.delegate haarCascadeController:self modificationDateOfFileAtPath:path];
	if (!date)
		date = [[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES] objectForKey:NSFileModificationDate];
	return date;
}



- (void)saveStorage;
{
	if (self.storageURL)
		[_detectionResults writeToURL:self.storageURL atomically:YES];
}


- (void)applicationWillTerminate:(NSNotification *)notification;
{
	[self saveStorage];
}


@end
