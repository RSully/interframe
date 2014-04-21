//
//  RSITrackHandlerInterpolate.h
//  interframe
//
//  Created by Ryan Sullivan on 4/17/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSITrackHandler.h"
#import "RSIInterpolationCompositing.h"

@class RSIAsynchronousVideoInterpolationRequest;

@interface RSITrackHandlerInterpolate : RSITrackHandler

-(id)initWithInputTrack:(AVAssetTrack *)inputTrack compositor:(id<RSIInterpolationCompositing>)compositor;

-(void)videoRequestFinishedCancelled:(RSIAsynchronousVideoInterpolationRequest *)request;
-(void)videoRequest:(RSIAsynchronousVideoInterpolationRequest *)request finishedWithFrame:(CVPixelBufferRef)frame;
-(void)videoRequest:(RSIAsynchronousVideoInterpolationRequest *)request finishedWithError:(NSError *)error;

@end
