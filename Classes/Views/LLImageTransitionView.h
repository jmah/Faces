//
//  LLImageTransitionView.h
//  Faces
//
//  Created by Jonathon Mah on 2008-07-09.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>


@interface LLImageTransitionView : NSView
{
	NSColor *_backgroundColor;
	NSArray *_imageKeys;
	NSString *_currentImageKey;
	NSImage *_currentImage;
    CIImage *_currentCIImage;
	CIImage *_transitionFromCIImage;
	
	CIFilter *_transition;
	
	NSTimeInterval _transitionStartTimeInterval;
	NSTimer *_transitionTimer;
}


@property(readwrite, copy) NSColor *backgroundColor;
@property(readwrite, copy) NSArray *imageKeys;
@property(readonly) NSTimeInterval imageInterval;
@property(readonly) NSTimeInterval transitionLength;
@property(readonly) NSUInteger transitionFrameRate;


@end
