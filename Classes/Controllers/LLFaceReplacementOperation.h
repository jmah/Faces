//
//  LLFaceReplacementOperation.h
//  Faces
//
//  Created by Jonathon Mah on 2008-07-09.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class LLController;


@interface LLFaceReplacementOperation : NSOperation
{
	NSMutableDictionary *_sourceItem;
	LLController *_controller;
	NSUInteger _minFaceCount;
}

- (id)initWithSourceItem:(NSMutableDictionary *)sourceItem controller:(LLController *)controller;
@property(readonly) NSMutableDictionary *sourceItem;
@property(readonly) LLController *controller;
@property(readonly) CGFloat rectOutsetFactor;
@property(readwrite) NSUInteger minFaceCount;

@end
