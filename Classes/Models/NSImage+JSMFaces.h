//
//  NSImage+JSMFaces.h
//  Faces
//
//  Created by Jonathon Mah on 2008-07-08.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenCV/OpenCV.h>


@interface NSImage (JSMFaces)

- (NSArray *)detectFaces;
- (IplImage *)copyIplImage;

@end