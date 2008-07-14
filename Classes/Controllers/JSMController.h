//
//  JSMController.h
//  Faces
//
//  Created by Jonathon Mah on 2008-07-08.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "JSMHaarCascadeController.h"
#import "JSMFaceExtractionOperation.h"


@interface JSMController : NSObject <JSMHaarCascadeDelegate, JSMFaceExtractionDelegate>
{
	JSMHaarCascadeController *_haarCascadeController;
	NSArray *_sourceItems;
	NSDictionary *_sourceItemModificationDatesByPath;
	NSMutableArray *_faces;
	NSOperationQueue *_faceExtractionQueue;
}


@property(readonly, copy) NSArray *sourceItems;
@property(readwrite, retain) NSMutableArray *faces;

@end
