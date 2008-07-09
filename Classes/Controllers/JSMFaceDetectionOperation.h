//
//  JSMFaceDetectionOperation.h
//  Faces
//
//  Created by Jonathon Mah on 2008-07-09.
//  Copyright 2008 Playhaus. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class JSMController;


@interface JSMFaceDetectionOperation : NSOperation
{
	NSMutableDictionary *_sourceItem;
	JSMController *_controller;
}

- (id)initWithSourceItem:(NSMutableDictionary *)sourceItem controller:(JSMController *)controller;
@property(readonly) NSMutableDictionary *sourceItem;
@property(readonly) JSMController *controller;
@property(readonly) CGFloat rectOutsetFactor;

@end
