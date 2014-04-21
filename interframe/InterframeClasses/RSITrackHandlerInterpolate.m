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
@property (strong) AVAssetWriterInputPixelBufferAdaptor *writerAdapter;

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

        self.writerAdapter = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:self.writerInput
                                                                        sourcePixelBufferAttributes:pixelBufferPoolAttributes];

        self.renderContext = [[RSIRenderContext alloc] _initWithAdapter:self.writerAdapter];
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

-(void)videoRequestFinishedCancelled:(RSIAsynchronousVideoInterpolationRequest *)request {
    @synchronized(self.queueRequests) {
        [self.queueRequests removeObject:request];
    }
}
-(void)videoRequest:(RSIAsynchronousVideoInterpolationRequest *)request finishedWithFrame:(CVPixelBufferRef)frame {

    [self queueAppendPixelBuffer:frame andTime:request.time source:@"videRequest:finishedWithFrame:"];

    @synchronized(self.queueRequests) {
        [self.queueRequests removeObject:request];
    }
}
-(void)videoRequest:(RSIAsynchronousVideoInterpolationRequest *)request finishedWithError:(NSError *)error {
    // TODO: something

    @synchronized(self.queueRequests) {
        [self.queueRequests removeObject:request];
    }
}

-(void)queueAppendPixelBuffer:(CVPixelBufferRef)buffer andTime:(CMTime)time source:(NSString *)source {
    CVPixelBufferRetain(buffer);
    @synchronized(self.queueBuffers) {
        [self.queueBuffers addObject:@{@"time": [NSValue valueWithCMTime:time], @"buffer": [NSValue valueWithPointer:buffer], @"source": source}];
    }
}

-(void)_readInputMedia {
//    CMItemCount samplesNum = CMSampleBufferGetNumSamples(sampleBuffer);
    CMSampleBufferRef priorSampleBuffer = NULL, sampleBuffer = NULL;
    BOOL wrotePriorSample = NO;
    RSIAsynchronousVideoInterpolationRequest *request = nil;

    priorSampleBuffer = [self.readerOutput copyNextSampleBuffer];

    if (!priorSampleBuffer)
    {
        self.isFinishedReading = YES;
        return;
    }

    while ((sampleBuffer = [self.readerOutput copyNextSampleBuffer]))
    {
        CMTime priorTime = CMSampleBufferGetPresentationTimeStamp(priorSampleBuffer);
        CMTime nextTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        CMTime inbetweenTime = CMTimeMake(round((priorTime.value + nextTime.value)/2.0), priorTime.timescale);

        CVImageBufferRef priorPixelBuffer = CMSampleBufferGetImageBuffer(priorSampleBuffer);
        CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);

        if (!wrotePriorSample)
        {
            [self queueAppendPixelBuffer:priorPixelBuffer andTime:priorTime source:@"_readInputMedia"];

            wrotePriorSample = YES;
        }
        [self queueAppendPixelBuffer:pixelBuffer andTime:nextTime source:@"_readInputMedia"];


        request = [[RSIAsynchronousVideoInterpolationRequest alloc] _initWithTrackHandler:self
                                                                            renderContext:self.renderContext
                                                                                     time:inbetweenTime
                                                                                withPrior:priorPixelBuffer
                                                                                     next:pixelBuffer];
        @synchronized(self.queueRequests) {
            [self.queueRequests addObject:request];
        }
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
        NSDictionary *vals;
        @synchronized(self.queueBuffers) {
            vals = [self.queueBuffers objectAtIndex:0];
            [self.queueBuffers removeObjectAtIndex:0];
        }

        CMTime time = [(NSValue *)vals[@"time"] CMTimeValue];
        CVPixelBufferRef buffer = [(NSValue *)vals[@"buffer"] pointerValue];

        NSLog(@"WRITING FOR TIME %f %@", CMTimeGetSeconds(time), vals[@"source"]);
        if (![vals[@"source"] isEqualToString:@"_readInputMedia"]){
        BOOL appended = [self.writerAdapter appendPixelBuffer:buffer withPresentationTime:time];
        if (!appended)
        {
            NSLog(@"WRITE FAILED OMG %p", self.writerAdapter.pixelBufferPool);
        }
        }

        CVPixelBufferRelease(buffer);
    }

    if (self.isFinishedReading && [self.queueRequests count] < 1)
    {
        [self markAsFinished];
    }
}

@end
