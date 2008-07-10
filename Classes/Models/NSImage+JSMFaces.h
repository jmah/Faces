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

- (NSString *)defaultCascadeName;
- (NSArray *)detectFaces;
- (NSArray *)detectFacesWithCascadeNamed:(NSString *)cascadeName;
- (NSArray *)detectFacesWithCascadeAtPath:(NSString *)cascadePath;
- (NSArray *)detectFacesWithCascade:(CvHaarClassifierCascade *)cascade;

// Caller has responsibility to cvReleaseImage(&iplImage);
- (IplImage *)copyIplImage;

@end
