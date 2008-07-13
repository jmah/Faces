//
//  NSImage+JSMHaarCascadeObjectDetection.h
//  Faces
//
//  Created by Jonathon Mah on 2008-07-08.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenCV/OpenCV.h>

extern NSString *JSMHaarCascadeFileExtension;


@interface NSImage (JSMHaarCascadeObjectDetection)

- (NSRectArray)detectObjectsWithHaarCascadeNamed:(NSString *)cascadeName count:(NSUInteger *)outCount;
- (NSRectArray)detectObjectsWithHaarCascadeAtPath:(NSString *)cascadePath count:(NSUInteger *)outCount;
- (NSRectArray)detectObjectsWithHaarCascade:(CvHaarClassifierCascade *)cascade count:(NSUInteger *)outCount;

// Caller has responsibility to cvReleaseImage(&iplImage);
- (IplImage *)copyIplImage;

@end
