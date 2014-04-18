//
//  RSIAsynchronousVideoInterpolationRequest.h
//  interframe
//
//  Created by Ryan Sullivan on 4/18/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "RSITrackHandler.h"
#import "RSIRenderContext.h"

@interface RSIAsynchronousVideoInterpolationRequest : NSObject

-(id)_initWithTrackHandler:(RSITrackHandler *)handler
             renderContext:(RSIRenderContext *)renderContext
                 withPrior:(CVPixelBufferRef)prior
                      next:(CVPixelBufferRef)next;

-(void)finishCancelledRequest;
-(void)finishWithComposedVideoFrame:(CVPixelBufferRef)frame;
-(void)finishWithError:(NSError *)error;

@property (nonatomic, readonly) CVPixelBufferRef sourceFramePrior;
@property (nonatomic, readonly) CVPixelBufferRef sourceFrameNext;

@property (nonatomic, strong, readonly) RSIRenderContext *renderContext;

@end
