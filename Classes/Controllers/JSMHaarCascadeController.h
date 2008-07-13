//
//  JSMHaarCascadeController.h
//  Faces
//
//  Created by Jonathon Mah on 2008-07-10.
//  Copyright 2008 Playhaus. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "JSMHaarCascadeDetectionOperation.h"


@class JSMHaarCascadeController;


@protocol JSMHaarCascadeDelegate

@optional

- (void)haarCascadeController:(JSMHaarCascadeController *)controller
			   didDetectRects:(NSRectArray)rects
						count:(NSUInteger)rectCount
			withCascadeAtPath:(NSString *)cascadePath
					 forImage:(NSImage *)image
					   atPath:(NSString *)path;

- (NSDate *)haarCascadeController:(JSMHaarCascadeController *)controller
	 modificationDateOfFileAtPath:(NSString *)path;

@end



@interface JSMHaarCascadeController : NSObject <JSMHaarCascadeDetectionOperationDelegate>
{
	NSURL *_storageURL;
	NSMutableDictionary *_detectionResults;
	NSOperationQueue *_detectionQueue;
	id <JSMHaarCascadeDelegate> _delegate;
}


- (id)initWithStorageURL:(NSURL *)url;
@property(readonly) NSURL *storageURL;
@property(readwrite, assign) id <JSMHaarCascadeDelegate> delegate;

- (void)beginDetectionOfImagesAtPaths:(NSArray *)paths withCascadeNamed:(NSString *)cascadeName;

- (void)saveStorage;

@end
