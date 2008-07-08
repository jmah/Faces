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
	NSImage *_image;
	IBOutlet NSArrayController *facesBucketController;
}


@property(readwrite, copy) NSImage *image;
@property(readonly) NSImage *imageWithHighlightedFaces;

- (void)extractFaces;

@end
