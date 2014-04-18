//
//  RSIAsynchronousVideoInterpolationRequest.m
//  interframe
//
//  Created by Ryan Sullivan on 4/18/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSIAsynchronousVideoInterpolationRequest.h"

@interface RSIAsynchronousVideoInterpolationRequest ()
@property (nonatomic, strong) RSFrameInterpolator *interpolator;
/*
 * Make public non-readonly
 */
@property (nonatomic) CVPixelBufferRef sourceFramePrior;
@property (nonatomic) CVPixelBufferRef sourceFrameNext;
@property (nonatomic) CMTime time;
@property (nonatomic, strong) RSIRenderContext *renderContext;
@end

@implementation RSIAsynchronousVideoInterpolationRequest

-(id)_initWithInterpolator:(RSFrameInterpolator *)interpolator
             renderContext:(RSIRenderContext *)renderContext
                      time:(CMTime)time
                 withPrior:(CVPixelBufferRef)prior
                      next:(CVPixelBufferRef)next {
    if ((self = [self init]))
    {
        self.interpolator = interpolator;
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

}
-(void)finishWithComposedVideoFrame:(CVPixelBufferRef)frame {

}
-(void)finishWithError:(NSError *)error {

}

@end
