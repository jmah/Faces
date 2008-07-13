//
//  JSMHaarCascadeDetectionOperation.m
//  Faces
//
//  Created by Jonathon Mah on 2008-07-14.
//  Copyright 2008 Playhaus. All rights reserved.
//

#import "JSMHaarCascadeDetectionOperation.h"
#import "JSMController.h"
#import "RMMessage.h"
#import "NSImage+JSMHaarCascadeObjectDetection.h"


@implementation JSMHaarCascadeDetectionOperation


- (id)initWithImageAtPath:(NSString *)path withModificationDate:(NSDate *)modificationDate usingCascadeAtPath:(NSString *)cascadePath withHash:(NSString *)cascadeHash delegate:(id <JSMHaarCascadeDetectionOperationDelegate>)delegate;
{
	if ((self = [super init]))
	{
		_path = path;
		_modificationDate = modificationDate;
		_cascadePath = cascadePath;
		_cascadeHash = cascadeHash;
		_delegate = delegate;
	}
	return self;
}


- (void)main;
{
	NSImage *image = [[NSImage alloc] initByReferencingFile:_path];
	if (!image || ![image isValid])
		return;
	if (self.isCancelled)
		return;
	
	NSUInteger count;
	NSRectArray rects = [image detectObjectsWithHaarCascadeAtPath:_cascadePath count:&count];
	if (self.isCancelled)
		return;
	
	RMMessage *callback = MSG(haarCascadeDetectionOperationDidDetectRects:rects
																	count:count
																 forImage:image
																   atPath:_path
													 withModificationDate:_modificationDate
													   usingCascadeAtPath:_cascadePath
																 withHash:_cascadeHash);
	[(id)_delegate performOnMainThread:callback waitUntilDone:NO];
}


@end
