//
//  RSIAsynchronousVideoInterpolationRequest.m
//  interframe
//
//  Created by Ryan Sullivan on 4/18/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSIAsynchronousVideoInterpolationRequest.h"

@interface RSIAsynchronousVideoInterpolationRequest ()
@property (nonatomic, strong) RSITrackHandlerInterpolate *handler;
/*
 * Make public non-readonly
 */
@property (nonatomic) CVPixelBufferRef sourceFramePrior;
@property (nonatomic) CVPixelBufferRef sourceFrameNext;
@property (nonatomic) CMTime time;
@property (nonatomic, strong) RSIRenderContext *renderContext;
@end

@implementation RSIAsynchronousVideoInterpolationRequest

-(id)_initWithTrackHandler:(RSITrackHandlerInterpolate *)handler
             renderContext:(RSIRenderContext *)renderContext
                      time:(CMTime)time
                 withPrior:(CVPixelBufferRef)prior
                      next:(CVPixelBufferRef)next {
    if ((self = [self init]))
    {
        self.handler = handler;
        self.renderContext = renderContext;

        self.time = time;

        self.sourceFramePrior = CVPixelBufferRetain(prior);
        self.sourceFrameNext = CVPixelBufferRetain(next);
    }
    return self;
}

-(void)dealloc {
    CVPixelBufferRelease(self.sourceFramePrior);
    CVPixelBufferRelease(self.sourceFrameNext);
}


-(void)finishCancelledRequest {
    [self.handler videoRequestFinishedCancelled:self];
}
-(void)finishWithComposedVideoFrame:(CVPixelBufferRef)frame {
    [self.handler videoRequest:self finishedWithFrame:frame];
}
-(void)finishWithError:(NSError *)error {
    [self.handler videoRequest:self finishedWithError:error];
}

@end
