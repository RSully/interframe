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

@interface RSITrackHandlerInterpolate () {
    CMSampleBufferRef _priorSampleBuffer;
}

@property (strong) id<RSIInterpolationCompositing> compositor;

@property (strong) RSIRenderContext *renderContext;

@end


@implementation RSITrackHandlerInterpolate

-(id)initWithInputTrack:(AVAssetTrack *)inputTrack compositor:(id<RSIInterpolationCompositing>)compositor
{
    if ((self = [self _initWithInputTrack:inputTrack readerSettings:[compositor sourcePixelBufferAttributes] writerSettings:nil]))
    {
        self.compositor = compositor;

        self.renderContext = [[RSIRenderContext alloc] _initWithWriterInput:self.writerInput
                                                           sourceAttributes:[compositor requiredPixelBufferAttributesForRenderContext]];
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

-(void)_mediaDataRequested {
    NSLog(@"-mediaDataRequested %@", self);

    if (!_priorSampleBuffer)
    {
        _priorSampleBuffer = [self.readerOutput copyNextSampleBuffer];
        if (!_priorSampleBuffer)
        {
            [self markAsFinished];
            return;
        }

        // TODO: add _priorSampleBuffer to writer
    }

    CMSampleBufferRef nextSampleBuffer = [self.readerOutput copyNextSampleBuffer];
    if (!nextSampleBuffer)
    {
        [self markAsFinished];
        return;
    }

    // TODO: get interpolated frame
    // TODO: add interpolated frame to writer

    // TODO: add nextSampleBuffer to writer

    // Swap prior for next
    CFRelease(_priorSampleBuffer);
    _priorSampleBuffer = nextSampleBuffer;
}

@end
