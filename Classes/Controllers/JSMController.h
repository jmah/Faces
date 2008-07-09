//
//  JSMController.h
//  Faces
//
//  Created by Jonathon Mah on 2008-07-08.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface JSMController : NSObject
{
	NSArray *_sourceItems;
	NSMutableArray *_faces;
	NSOperationQueue *_faceDetectionQueue;
	IBOutlet NSProgressIndicator *progressBar;
}


@property(readonly, copy) NSArray *sourceItems;
@property(readwrite, retain) NSMutableArray *faces;

- (void)addFaces:(NSArray *)faces;
- (void)updateProgressBar;

@end
