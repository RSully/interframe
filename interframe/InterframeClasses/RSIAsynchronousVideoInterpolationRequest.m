//
//  RSIAsynchronousVideoInterpolationRequest.m
//  interframe
//
//  Created by Ryan Sullivan on 4/18/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSIAsynchronousVideoInterpolationRequest.h"

@interface RSIAsynchronousVideoInterpolationRequest ()
@property (nonatomic, strong) RSITrackHandler *handler;
/*
 * Make public non-readonly
 */
@property (nonatomic) CVPixelBufferRef sourceFramePrior;
@property (nonatomic) CVPixelBufferRef sourceFrameNext;
@property (nonatomic, strong) RSIRenderContext *renderContext;
@end

@implementation RSIAsynchronousVideoInterpolationRequest

-(id)_initWithTrackHandler:(RSITrackHandler *)handler
             renderContext:(RSIRenderContext *)renderContext
                 withPrior:(CVPixelBufferRef)prior
                      next:(CVPixelBufferRef)next {
    if ((self = [self init]))
    {
        self.handler = handler;
        self.renderContext = renderContext;

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
    NSLog(@"-finishCancelledRequest");
}
-(void)finishWithComposedVideoFrame:(CVPixelBufferRef)frame {
    NSLog(@"-finishWithComposedVideoFrame");
}
-(void)finishWithError:(NSError *)error {
    NSLog(@"-finishWithError ***: %@", error);
}

@end
