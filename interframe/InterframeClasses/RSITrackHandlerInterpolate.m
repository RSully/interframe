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

@interface RSITrackHandlerInterpolate ()

@property (strong) id<RSIInterpolationCompositing> compositor;

@property (strong) RSIRenderContext *renderContext;

@end


@implementation RSITrackHandlerInterpolate

-(id)initWithInputTrack:(AVAssetTrack *)inputTrack compositor:(id<RSIInterpolationCompositing>)compositor
{
    if ((self = [self _initWithInputTrack:inputTrack readerSettings:[compositor sourcePixelBufferAttributes] writerSettings:nil]))
    {
        self.compositor = compositor;

        self.renderContext = [[RSIRenderContext alloc] _initWithWriterInput:self.writerInput sourceAttributes:[compositor requiredPixelBufferAttributesForRenderContext]];
        [compositor renderContextChanged:self.renderContext];
    }
    return self;
}

-(void)_mediaDataRequested {
    NSLog(@"-mediaDataRequested %@", self);
    [self markAsFinished];
}

@end
