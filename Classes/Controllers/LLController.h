//
//  LLController.h
//  Faces
//
//  Created by Jonathon Mah on 2008-07-09.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class LLImageTransitionView;


@interface LLController : NSObject
{
	NSArray *_sourceItems;
	NSMutableArray *_maskImages;
	NSMutableArray *_luchadorImages;
	NSOperationQueue *_faceDetectionQueue;
	
	IBOutlet NSProgressIndicator *progressSpinner;
	IBOutlet LLImageTransitionView *imageTransitionView;
}


@property(readonly) NSArray *maskImages;
@property(readonly, copy) NSArray *sourceItems;
@property(readonly) NSArray *luchadorImages;

- (void)addLuchadorImage:(NSImage *)image forItemWithUUID:(NSString *)uuid;

@end
