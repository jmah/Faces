//
//  LLController.h
//  Faces
//
//  Created by Jonathon Mah on 2008-07-09.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "JSMHaarCascadeController.h"

@class LLImageTransitionView;


@interface LLController : NSObject <JSMHaarCascadeDelegate>
{
	JSMHaarCascadeController *_haarCascadeController;
	NSMutableArray *_maskImages;
	NSDictionary *_sourceItemModificationDatesByPath;
	NSMutableDictionary *_luchadorImages;
	
	IBOutlet NSProgressIndicator *progressSpinner;
	IBOutlet LLImageTransitionView *imageTransitionView;
}


@property(readonly) NSArray *maskImages;
@property(readonly) NSArray *allImageKeys;
@property(readonly) NSUInteger minFaceCount;

- (NSImage *)imageForKey:(NSString *)key;

@end
