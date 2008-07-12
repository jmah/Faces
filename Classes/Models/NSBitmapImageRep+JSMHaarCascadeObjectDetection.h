//
//  NSBitmapImageRep+JSMHaarCascadeObjectDetection.h
//  Faces
//
//  Created by Jonathon Mah on 2008-07-08.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenCV/OpenCV.h>


@interface NSBitmapImageRep (JSMHaarCascadeObjectDetection)

// Caller has responsibility to cvReleaseImage(&iplImage);
- (IplImage *)copyIplImage;

@end
