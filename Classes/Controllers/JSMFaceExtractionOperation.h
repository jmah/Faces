//
//  JSMFaceDetectionOperation.h
//  Faces
//
//  Created by Jonathon Mah on 2008-07-09.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol JSMFaceExtractionDelegate

@optional
- (void)addFaces:(NSArray *)faces;

@end



@interface JSMFaceExtractionOperation : NSOperation
{
	NSImage *_image;
	__strong NSRectArray _rects;
	NSUInteger _rectCount;
	id <JSMFaceExtractionDelegate> _delegate;
}


- (id)initWithImage:(NSImage *)image rects:(NSRectArray)rects count:(NSUInteger)rectCount delegate:(id <JSMFaceExtractionDelegate>)delegate;
@property(readonly) CGFloat rectOutsetFactor;

@end
