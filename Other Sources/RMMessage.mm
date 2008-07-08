//***************************************************************************

// Copyright (C) 2007 Sigil Studios Pty Ltd
// Copyright (C) 2007 Ofri Wolfus
// 
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject
// to the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
// ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

//***************************************************************************

// Yes, we know that objc_msgSendv() and friends are deprecated in
// Mac OS X 10.5... no need to throw up 17 warnings about it.

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
#	if !defined(__OBJC2__) && defined(OBJC2_UNAVAILABLE)
#		undef OBJC2_UNAVAILABLE
#		define OBJC2_UNAVAILABLE
#	endif
#endif

//***************************************************************************

#include <map>
#include <vector>
#include <tr1/unordered_map>

#include <math.h>

#include <sys/types.h>
#include <sys/sysctl.h>

#include <objc/objc-runtime.h>

#import <Foundation/NSDebug.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSProxy.h>
#import <Foundation/NSThread.h>

#import "RMMessage.h"

#import <Cocoa/Cocoa.h>

//***************************************************************************

// TODO: Use [RMMessage x] for MSG()
// TODO: Don't use NSEnumerator (slow)
// TODO: Make it work with class methods too
// TODO: Make thread-safe
// TODO: Consider making RMMessage not a subclass of NSProxy

//***************************************************************************

static unsigned MaximumArgumentSizeForSelector(const SEL selector);

//***************************************************************************

@interface NSInvocation (RMMessageFrame)

- (void*)argumentFrame;

@end

//---------------------------------------------------------------------------

@implementation NSInvocation (RMMessageFrame)

static unsigned MacOSXMajorVersion()
{
	static int major = -1;
	
	if(major == -1)
	{
		SInt32 MacVersion;
		Gestalt(gestaltSystemVersion, &MacVersion);
		
		major = (MacVersion & 0x00F0) >> 4;
	}
	
	return major;
}

- (void*)argumentFrame
{
#ifdef __OBJC2__
	return _frame;
#else
	Ivar frameIvar = class_getInstanceVariable([self class], MacOSXMajorVersion() == 5 ? "_frame" : "argumentFrame");
	
	void** pFrame = (void**) ( (char*)self+(frameIvar->ivar_offset) );
	return *pFrame;
#endif
}

@end

//***************************************************************************

@implementation RMMessage

- (id)forward:(SEL)sel :(marg_list)args
{
	selector = sel;
	
	argumentSize = MaximumArgumentSizeForSelector(sel)+marg_prearg_size;
	memcpy(arguments, args, argumentSize);
	
	return self;
}

- (id)forwardingPrototype:a:b:c:d:e:f:g:h:i:j:k:l:m:n:o:p:q:r:s:t:u:v:w:x:y:z
{
	return nil;
}

- (NSMethodSignature*)methodSignatureForSelector:(SEL)aSelector
{
	static const SEL forwardingPrototypeSelector = @selector(forwardingPrototype: : : : : : : : : : : : : : : : : : : : : : : : : :);
	
	if(aSelector == forwardingPrototypeSelector) return [super methodSignatureForSelector:aSelector];
	else return [super methodSignatureForSelector:forwardingPrototypeSelector];
}

- (void)forwardInvocation:(NSInvocation*)anInvocation
{
	selector = [anInvocation selector];
	
	argumentSize = MaximumArgumentSizeForSelector(selector)+marg_prearg_size;
	memcpy(arguments, [anInvocation argumentFrame], argumentSize);
	
	[anInvocation setReturnValue:&self];
}

@end

//***************************************************************************

@implementation NSArray (HOM)

static BOOL (*boolMsgSendv)(id, SEL, unsigned, marg_list) = (BOOL (*)(id, SEL, unsigned, marg_list)) objc_msgSendv;
static id (*idMsgSendv)(id, SEL, unsigned, marg_list) = (id (*)(id, SEL, unsigned, marg_list)) objc_msgSendv;
static void (*voidMsgSendv)(id, SEL, unsigned, marg_list) = (void (*)(id, SEL, unsigned, marg_list)) objc_msgSendv;

- (id)collect:(RMMessage*)message
{
	NSMutableArray* collectedArray = [NSMutableArray array];
	
	NSEnumerator* e = [self objectEnumerator];
	while(id object = [e nextObject])
	{
		id returnValue = idMsgSendv(object, message->selector, message->argumentSize, message->arguments);
		[collectedArray addObject:returnValue];
	}

	return collectedArray;
}

- (void)mutableReplacingCollect:(NSArray*)originalArray newVector:(std::vector<id>&)collectedVector range:(const NSRange)range message:(RMMessage*)message
{
	for(unsigned i = range.location; i < NSMaxRange(range); i++)
	{
		id object = [originalArray objectAtIndex:i];
		collectedVector[i] = idMsgSendv(object, message->selector, message->argumentSize, message->arguments);
	}
}

static unsigned NumberOfCPUs()
{
	unsigned oldNumberOfCPUs = 0;
	size_t oldNumberOfCPUsSize = sizeof(oldNumberOfCPUs);
	
	sysctlbyname("hw.ncpu", &oldNumberOfCPUs, &oldNumberOfCPUsSize, NULL, 0);
	
	return oldNumberOfCPUs;
}

- (id)parallelCollect:(RMMessage*)message
{
	const float tasksPerProcessor = static_cast<float>([self count]) / static_cast<float>(NumberOfCPUs());

	std::vector<id> collectedVector([self count]);
	
	for(float floatingIndex = 0.0f; floatingIndex < [self count]; floatingIndex += tasksPerProcessor)
	{
		const unsigned lowerLimit = ceilf(floatingIndex);
		const unsigned upperLimit = ceilf(floatingIndex+tasksPerProcessor);
		
		[self detachNewThreadSelector:MSG(mutableReplacingCollect:self newVector:collectedVector range:NSMakeRange(lowerLimit, upperLimit-lowerLimit) message:message)];
	}
	
	NSArray* collectedArray = [[[NSArray alloc] initWithObjects:&collectedVector[0] count:collectedVector.size()] autorelease];
	
	return collectedArray;
}

- (id)select:(RMMessage*)message
{
	NSMutableArray* collectedArray = [NSMutableArray array];
	
	NSEnumerator* e = [self objectEnumerator];
	while(id object = [e nextObject])
	{
		const BOOL returnValue = boolMsgSendv(object, message->selector, message->argumentSize, message->arguments);

		if(returnValue) [collectedArray addObject:object];
	}
	
	return collectedArray;
}

@end

//***************************************************************************

@implementation RMPerformOnMainThreadAssistant

@end

//***************************************************************************

@interface RMMessageBackgroundThread : NSThread
{
	id _target;
	RMMessage* _message;
}

- (id)initWithTarget:(id)target message:(RMMessage*)message;

@end

//***************************************************************************

@implementation NSObject (PerformOnMainThreadHigherOrderMessaging)

- (id)performMessage:(RMMessage*)message
{
	return idMsgSendv(self, message->selector, message->argumentSize, message->arguments);
}

- (void)performMessageInBackground:(RMMessage*)message
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	voidMsgSendv(self, message->selector, message->argumentSize, message->arguments);
	
	[pool release];
}

static void PerformMessageCapturingReturnValue(id self, RMMessage* message)
{
	RMPerformOnMainThreadAssistant* assistant = message->captureObject;
	
	NSMethodSignature* methodSignature = [self methodSignatureForSelector:message->selector];
	switch([methodSignature methodReturnType][0])
	{
		case _C_VOID:
			voidMsgSendv(self, message->selector, message->argumentSize, message->arguments);
			assistant->returnValue = [NSNull null];
			break;
		case _C_ID:		
			assistant->returnValue = [idMsgSendv(self, message->selector, message->argumentSize, message->arguments) retain];
			break;
		case _C_CHR:
			assistant->returnValue = [[NSNumber numberWithBool:(boolMsgSendv(self, message->selector, message->argumentSize, message->arguments))] retain];
			break;
	}
}

+ (void)performMessageCapturingReturnValue:(RMMessage*)message
{
	PerformMessageCapturingReturnValue(self, message);
}

- (void)performMessageCapturingReturnValue:(RMMessage*)message
{
	PerformMessageCapturingReturnValue(self, message);
}

static id PerformOnMainThread(id self, RMMessage* message)
{
	RMPerformOnMainThreadAssistant* assistant = [[RMPerformOnMainThreadAssistant alloc] init];
	message->captureObject = assistant;
	
	[self performSelectorOnMainThread:@selector(performMessageCapturingReturnValue:) withObject:message waitUntilDone:YES];
	[assistant release];
	
	return [assistant->returnValue autorelease];
}

+ (id)performOnMainThread:(RMMessage*)message
{
	return PerformOnMainThread(self, message);
}

- (id)performOnMainThread:(RMMessage*)message
{
	return PerformOnMainThread(self, message);
}

- (void)performOnMainThread:(RMMessage*)message waitUntilDone:(BOOL)wait
{
	[self performSelectorOnMainThread:@selector(performMessage:) withObject:message waitUntilDone:wait];
}

- (id)performOnBackgroundThread:(RMMessage*)message
{
	if(pthread_main_np() == 0)
	{
		NSLog(@"-[%@ performOnBackgroundThread:] called from non-main thread; returning nil", [self className]);
		return nil;
	}
	
	RMPerformOnMainThreadAssistant* assistant = [[RMPerformOnMainThreadAssistant alloc] init];
	message->captureObject = assistant;
	
	RMMessageBackgroundThread* backgroundThread = [[RMMessageBackgroundThread alloc] initWithTarget:self message:message];
	[backgroundThread start];
	while(![backgroundThread isFinished]) [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
	[backgroundThread release];

	return [assistant->returnValue autorelease];
}

- (void)detachNewThreadSelector:(RMMessage*)message
{
	[NSThread detachNewThreadSelector:@selector(performMessageInBackground:) toTarget:self withObject:message];
}

- (void)performOnBackgroundThreadFinished
{
	// This is just a dummy method that -performOnBackgroundThread will eventually call via the run loop when the background thread's operations are finished.
}

@end

//***************************************************************************

@implementation RMMessageBackgroundThread

- (id)initWithTarget:(id)target message:(RMMessage*)message
{
	self = [super init];
	if(self == nil) return nil;
	
	_target = target;
	_message = message;
	
	return self;
}

- (void)main
{
	NSAutoreleasePool* pool = [NSAutoreleasePool new];
	
	[_target performMessageCapturingReturnValue:_message];
	
	// We call a dummy method here on the main thread, so that the main thread's runloop gets triggered and knows that we're finished.  There's a race condition here where the dummy method will get called before this method finishes, so that this thread isn't finished running yet when and main thread's runloop keeps waiting.  That's not really a big concern for the momen; it just means that there'll be a small delay before the main thread gets control back.   In practice, the race condition doesn't seem to happen very often, and it's not catastrophic if it does.
	[_target performSelectorOnMainThread:@selector(performOnBackgroundThreadFinished) withObject:nil waitUntilDone:NO];
	
	[pool drain];
}

@end

//***************************************************************************

typedef std::tr1::unordered_map<SEL, unsigned> SelectorMap;
static SelectorMap allSelectorsToArgumentSizeMap;

//***************************************************************************

#define	DISPLAY_CACHE_STATISTICS 0

/// Returns 0 if a selector wasn't cached yet, 1 if a selector already exists but the replacement was the same size,
/// and 2 if a selector already exists and was a different size
static inline unsigned CacheMaximumArgumentSizeForSelector(const SEL selector, const unsigned argumentSize)
{
	const SelectorMap::iterator& searchIterator = allSelectorsToArgumentSizeMap.find(selector);
	
	if(searchIterator == allSelectorsToArgumentSizeMap.end())
	{
		allSelectorsToArgumentSizeMap[selector] = argumentSize;
		return 0;
	}
	else
	{
		if(argumentSize > (*searchIterator).second)
		{
			allSelectorsToArgumentSizeMap[selector] = argumentSize;
		}
		else if(argumentSize == (*searchIterator).second)
		{
			return 1;
		}
	}
	
#if DISPLAY_CACHE_STATISTICS
	NSLog(@"selector %s has conflicting size: %u vs %u",
		  selector, argumentSize, (*searchIterator).second);
#endif
	
	return 2;
}

static void CacheAllSelectors()
{
	static int previousNumberOfClasses = 0;
	const int numberOfClasses = objc_getClassList(NULL, 0);
	
	if(numberOfClasses == previousNumberOfClasses) return;
	
	std::vector<Class> classList(numberOfClasses);
	objc_getClassList(&classList[0], numberOfClasses);
	
	allSelectorsToArgumentSizeMap.clear();
	
	unsigned numberOfSharedSelectors = 0;
	unsigned numberOfSelectorsWithDifferentSize = 0;
	unsigned totalNumberOfSelectors = 0;
	
	for(int i = 0; i < numberOfClasses; i++)
	{
		// class_nextMethodList is documented in objc-class.h and takes take of all the CLS_METHOD_ARRAY flag checking.
		
		void* methodListIterator = 0;
		while(objc_method_list* pMethodList = class_nextMethodList(classList[i], &methodListIterator))
		{
			objc_method_list& methodList = *pMethodList;
			
			for(int i = 0; i < methodList.method_count; i++)
			{
				Method pMethod = &(methodList.method_list[i]);
				
				const unsigned sizeOfArguments = method_getSizeOfArguments(pMethod);
				const unsigned cacheReturnValue = CacheMaximumArgumentSizeForSelector(pMethod->method_name, sizeOfArguments);
				switch(cacheReturnValue)
				{
					case 1:
						numberOfSharedSelectors++;
						break;
					case 2:
						numberOfSelectorsWithDifferentSize++;
#if DISPLAY_CACHE_STATISTICS
						NSLog(@"... in class name %s", classList[i]->name);
#endif
						break;
					default:
						break;
				}
				
				totalNumberOfSelectors++;
			}
		}
	}

	previousNumberOfClasses = numberOfClasses;
	
#if DISPLAY_CACHE_STATISTICS
	
	const float percentageOfSharedSelectorsVersusTotal = ((float)numberOfSharedSelectors/(float)totalNumberOfSelectors)*100.0f;
	const float percentageOfConflictingSelectorsVersusTotal = ((float)numberOfSelectorsWithDifferentSize/(float)totalNumberOfSelectors)*100.0f;
	const float percentageOfConflictingSelectorsVersusShared = ((float)numberOfSelectorsWithDifferentSize/(float)numberOfSharedSelectors)*100.0f;
	const unsigned stepsToSearchTotalSelectorCache = sqrtf(totalNumberOfSelectors);
	
	NSLog(@"Statistics:\n"
		  @"Number of classes: %u\n"
		  @"Total number of selectors: %u (%u average steps to search total selector cache tree)\n"
		  @"Number of shared selectors: %u (%.0f%%)\n"
		  @"Number of selected with conflicting sizes: %u (%.2f%% of total, %.2f%% of shared)\n",
		  numberOfClasses,
		  totalNumberOfSelectors, stepsToSearchTotalSelectorCache,
		  numberOfSharedSelectors, percentageOfSharedSelectorsVersusTotal,
		  numberOfSelectorsWithDifferentSize, percentageOfConflictingSelectorsVersusTotal, percentageOfConflictingSelectorsVersusShared);
#endif
}

/// Returns 0 if the selector couldn't be found at all
static inline unsigned MaximumArgumentSizeForSelector(const SEL selector)
{
	CacheAllSelectors();
	
	static SelectorMap mostRecentlyUsedSelectorToArgumentSizeMap;	
	const SelectorMap::iterator& mostRecentlyUsedIterator = mostRecentlyUsedSelectorToArgumentSizeMap.find(selector);
	if(mostRecentlyUsedIterator != mostRecentlyUsedSelectorToArgumentSizeMap.end()) return (*mostRecentlyUsedIterator).second;

	const SelectorMap::iterator& allSelectorsIterator = allSelectorsToArgumentSizeMap.find(selector);
	
	if(allSelectorsIterator == allSelectorsToArgumentSizeMap.end())
	{
		// We couldn't find the selector in the selector cache, which can happen if, for example, we invoke a class method.  In this case, be safe and return the maximum argument buffer size
		
		return RMMESSAGE_ARGUMENT_BUFFER_SIZE;
	}
	else
	{
		const unsigned sizeOfArgument = (*allSelectorsIterator).second;
		mostRecentlyUsedSelectorToArgumentSizeMap[selector] = sizeOfArgument;
		return sizeOfArgument;
	}
}

//***************************************************************************

