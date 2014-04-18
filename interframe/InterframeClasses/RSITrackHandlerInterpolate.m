//
//  RSITrackHandlerInterpolate.m
//  interframe
//
//  Created by Ryan Sullivan on 4/17/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSITrackHandlerInterpolate.h"
#import "RSIRenderContext.h"
#import "RSIInterpolationCompositing.h"
#import "RSIAsynchronousVideoInterpolationRequest.h"

@interface RSITrackHandlerInterpolate () {
    CMSampleBufferRef _priorSampleBuffer;
}

@property (strong) id<RSIInterpolationCompositing> compositor;
@property (strong) RSIRenderContext *renderContext;

@property (strong) dispatch_queue_t readingQueue;
@property (strong) NSMutableArray *queueRequests;
@property (strong) NSMutableArray *queueBuffers;

@property BOOL isFinishedReading;

@end


@implementation RSITrackHandlerInterpolate

-(id)initWithInputTrack:(AVAssetTrack *)inputTrack compositor:(id<RSIInterpolationCompositing>)compositor
{
    if ((self = [self _initWithInputTrack:inputTrack readerSettings:[compositor sourcePixelBufferAttributes] writerSettings:nil]))
    {
        self.readingQueue = dispatch_queue_create("me.rsullivan.interframe.interpolateHandler", DISPATCH_QUEUE_SERIAL);
        self.queueRequests = [NSMutableArray new];
        self.queueBuffers = [NSMutableArray new];
        self.isFinishedReading = NO;

        self.compositor = compositor;

        NSMutableDictionary *pixelBufferPoolAttributes = [[compositor requiredPixelBufferAttributesForRenderContext] mutableCopy];
        pixelBufferPoolAttributes[(NSString *)kCVPixelBufferWidthKey] = @(inputTrack.naturalSize.width);
        pixelBufferPoolAttributes[(NSString *)kCVPixelBufferHeightKey] = @(inputTrack.naturalSize.height);

        self.renderContext = [[RSIRenderContext alloc] _initWithWriterInput:self.writerInput
                                                           sourceAttributes:pixelBufferPoolAttributes];
        [compositor renderContextChanged:self.renderContext];
    }
    return self;
}

-(void)dealloc {
    if (_priorSampleBuffer)
    {
        CFRelease(_priorSampleBuffer), _priorSampleBuffer = NULL;
    }
}

-(void)startHandlingWithCompletionHandler:(void (^)(void))completionHandler {
    dispatch_async(self.readingQueue, ^{
        [self _readInputMedia];
    });

    [super startHandlingWithCompletionHandler:completionHandler];
}

-(void)_readInputMedia {
//    CMItemCount samplesNum = CMSampleBufferGetNumSamples(sampleBuffer);
    CMSampleBufferRef priorSampleBuffer = NULL, sampleBuffer = NULL;
    RSIAsynchronousVideoInterpolationRequest *request = nil;

    priorSampleBuffer = [self.readerOutput copyNextSampleBuffer];
    // TODO: append prior to queue

    while ((sampleBuffer = [self.readerOutput copyNextSampleBuffer]))
    {
        // TODO: append next to queue


        request = [[RSIAsynchronousVideoInterpolationRequest alloc] _initWithInterpolator:self
                                                                            renderContext:self.renderContext
                                                                                     time:kCMTimeInvalid // TODO: time maybe? get rid of it?
                                                                                withPrior:CMSampleBufferGetImageBuffer(priorSampleBuffer)
                                                                                     next:CMSampleBufferGetImageBuffer(sampleBuffer)];
        [self.queueRequests addObject:request];
        [self.compositor startVideoCompositionRequest:request];

        CFRelease(priorSampleBuffer);
        priorSampleBuffer = sampleBuffer;
    }
    CFRelease(priorSampleBuffer);

    self.isFinishedReading = YES;
}
-(void)_mediaDataRequested {
    NSLog(@"-mediaDataRequested %@", self);

    if ([self.queueBuffers count])
    {
        // append buffer
    }

    if (self.isFinishedReading && [self.queueRequests count] < 1)
    {
        [self markAsFinished];
    }
}

@end
