//
//  JSMHaarCascadeDetectionOperation.h
//  Faces
//
//  Created by Jonathon Mah on 2008-07-14.
//  Copyright 2008 Playhaus. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol JSMHaarCascadeDetectionOperationDelegate

@optional
- (void)haarCascadeDetectionOperationDidDetectRects:(NSRectArray)rects
											  count:(NSUInteger)rectCount
										   forImage:(NSImage *)image
											 atPath:(NSString *)imagePath
							   withModificationDate:(NSDate *)modificationDate
								 usingCascadeAtPath:(NSString *)cascadePath
										   withHash:(NSString *)cascadeHash;

@end


@interface JSMHaarCascadeDetectionOperation : NSOperation
{
	NSString *_path;
	NSDate *_modificationDate;
	NSString *_cascadePath;
	NSString *_cascadeHash;
	id <JSMHaarCascadeDetectionOperationDelegate> _delegate;
}


- (id)initWithImageAtPath:(NSString *)path withModificationDate:(NSDate *)modificationDate usingCascadeAtPath:(NSString *)cascadePath withHash:(NSString *)cascadeHash delegate:(id <JSMHaarCascadeDetectionOperationDelegate>)delegate;

@end
