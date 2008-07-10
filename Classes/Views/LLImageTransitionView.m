//
//  LLImageTransitionView.m
//  Faces
//
//  Created by Jonathon Mah on 2008-07-09.
//  Copyright 2008 Jonathon Mah. All rights reserved.
//

#import "LLImageTransitionView.h"


@interface LLImageTransitionView ()

- (void)scheduleIntervalTimer;
- (NSImage *)nextRandomImage;

@end


@implementation LLImageTransitionView

- (id)initWithFrame:(NSRect)frame;
{
	if ((self = [super initWithFrame:frame]))
	{
		_backgroundColor = [NSColor whiteColor];
		_images = [NSArray array];
		_transitionStartTimeInterval = 0.0;
		
		_transition = [CIFilter filterWithName:@"CISwipeTransition"
								 keysAndValues:@"inputColor", [CIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.0f],
											   @"inputAngle", [NSNumber numberWithFloat:0.0f],
											   @"inputWidth", [NSNumber numberWithFloat:12.0f],
											   @"inputOpacity", [NSNumber numberWithFloat:0.0f],
											   nil];
	}
	return self;
}


- (void)viewDidMoveToSuperview;
{
	[super viewDidMoveToSuperview];
	[self scheduleIntervalTimer];
}


@synthesize backgroundColor = _backgroundColor;
@synthesize images = _images;


- (void)setImages:(NSArray *)images;
{
	_images = [images copy];
	
	if (!_currentImage)
	{
		_currentImage = [self nextRandomImage];
		[self setNeedsDisplay:YES];
	}
}


- (NSTimeInterval)imageInterval;
{
	return 7.0;
}


- (NSTimeInterval)transitionLength;
{
	return 3.0;
}


- (NSUInteger)transitionFrameRate;
{
	return 15;
}


- (void)scheduleIntervalTimer;
{
	NSTimer *intervalTimer = [NSTimer timerWithTimeInterval:self.imageInterval
													 target:self
												   selector:@selector(intervalTimerFired:)
												   userInfo:nil
													repeats:NO];
	[[NSRunLoop currentRunLoop] addTimer:intervalTimer forMode:NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:intervalTimer forMode:NSEventTrackingRunLoopMode];
}


- (void)drawRect:(NSRect)rect
{
	[self.backgroundColor set];
	NSRectFill(rect);
	
	if (!_currentImage)
		return;
	if (!_currentCIImage)
		_currentCIImage = [CIImage imageWithData:[_currentImage TIFFRepresentation]];
	if (!_transitionFromCIImage)
		_transitionFromCIImage = _currentCIImage;
	
	CIVector *boundsVector = [CIVector vectorWithX:0 Y:0 Z:NSWidth([self bounds]) W:NSHeight([self bounds])];
	
	// Scale and translate from image
	CGRect fromExtent = [_transitionFromCIImage extent];
	CGFloat fromScale = MIN(boundsVector.Z / CGRectGetWidth(fromExtent),
							boundsVector.W / CGRectGetHeight(fromExtent));
	NSAffineTransform *fromTransform = [NSAffineTransform transform];
	[fromTransform translateXBy:((boundsVector.Z - CGRectGetWidth(fromExtent) * fromScale) / 2.0f)
							yBy:((boundsVector.W - CGRectGetHeight(fromExtent) * fromScale) / 2.0f)];
	[fromTransform scaleBy:fromScale];
	CIFilter *from = [CIFilter filterWithName:@"CIAffineTransform"
								keysAndValues:@"inputImage", _transitionFromCIImage,
											  @"inputTransform", fromTransform,
											  nil];
	
	// Scale and translate to image
	CGRect toExtent = [_currentCIImage extent];
	CGFloat toScale = MIN(boundsVector.Z / CGRectGetWidth([_currentCIImage extent]),
						  boundsVector.W / CGRectGetHeight([_currentCIImage extent]));
	NSAffineTransform *toTransform = [NSAffineTransform transform];
	[toTransform translateXBy:((boundsVector.Z - CGRectGetWidth(toExtent) * toScale) / 2.0f)
						  yBy:((boundsVector.W - CGRectGetHeight(toExtent) * toScale) / 2.0f)];
	[toTransform scaleBy:toScale];
	CIFilter *to = [CIFilter filterWithName:@"CIAffineTransform"
							  keysAndValues:@"inputImage", _currentCIImage,
											@"inputTransform", toTransform,
											nil];
	
	// Set up transition
	CGFloat transitionProgress = ([NSDate timeIntervalSinceReferenceDate] - _transitionStartTimeInterval) / self.transitionLength;
	if (transitionProgress < 0.0f)
		transitionProgress = 0.0f;
	else if (transitionProgress > 1.0f)
		transitionProgress = 1.0f;
	[_transition setValue:[NSNumber numberWithFloat:0.5f * (1.0f - cos(transitionProgress * M_PI))]
				   forKey:@"inputTime"];
	[_transition setValue:boundsVector forKey:@"inputExtent"];
	[_transition setValue:[to valueForKey:@"outputImage"] forKey:@"inputTargetImage"];
	[_transition setValue:[from valueForKey:@"outputImage"] forKey:@"inputImage"];
	
	// Crop the output
	CIFilter *crop = [CIFilter filterWithName:@"CICrop"
								keysAndValues:@"inputImage", [_transition valueForKey: @"outputImage"],
											  @"inputRectangle", boundsVector,
											  nil];
	
	// Draw to screen
	CIImage *image = [crop valueForKey:@"outputImage"];
	CIContext *context = [[NSGraphicsContext currentContext] CIContext];
	[context drawImage:image inRect:NSRectToCGRect([self bounds]) fromRect:[image extent]];
}


- (NSImage *)nextRandomImage;
{
	NSArray *candidateImages = self.images;
	if (_currentImage)
	{
		// Pick a different image
		NSMutableArray *otherImages = [self.images mutableCopy];
		[otherImages removeObjectIdenticalTo:_currentImage];
		candidateImages = otherImages;
	}
	if ([candidateImages count] > 0)
		return [candidateImages objectAtIndex:(random() % [candidateImages count])];
	else
		return nil;
}


- (void)intervalTimerFired:(NSTimer *)timer;
{
	NSImage *nextImage = [self nextRandomImage];
	if (nextImage && (nextImage != _currentImage))
	{
		_transitionFromCIImage = _currentCIImage;
		_currentImage = nextImage;
		_currentCIImage = nil;
		
		[_transitionTimer invalidate], _transitionTimer = nil;
		_transitionTimer = [NSTimer timerWithTimeInterval:(1.0 / self.transitionFrameRate)
												   target:self
												 selector:@selector(transitionTimerFired:)
												 userInfo:nil
												  repeats:YES];
		_transitionStartTimeInterval = [NSDate timeIntervalSinceReferenceDate];
		[[NSRunLoop currentRunLoop] addTimer:_transitionTimer forMode:NSDefaultRunLoopMode];
		[[NSRunLoop currentRunLoop] addTimer:_transitionTimer forMode:NSEventTrackingRunLoopMode];
	}
	else
		[self scheduleIntervalTimer];
}


- (void)transitionTimerFired:(NSTimer *)timer;
{
	if (([NSDate timeIntervalSinceReferenceDate] - _transitionStartTimeInterval) >= self.transitionLength)
	{
		[_transitionTimer invalidate], _transitionTimer = nil;
		[self scheduleIntervalTimer];
	}
	[self setNeedsDisplay:YES];
}


@end
