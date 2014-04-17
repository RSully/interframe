//
//  RSITrackHandlerInterpolate.m
//  interframe
//
//  Created by Ryan Sullivan on 4/17/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSITrackHandlerInterpolate.h"

@interface RSITrackHandlerInterpolate ()

@property (strong) id<AVVideoCompositing> compositor;

@end


@implementation RSITrackHandlerInterpolate

-(id)initWithInputTrack:(AVAssetTrack *)inputTrack compositor:(id<AVVideoCompositing>)compositor
{
    if ((self = [self init]))
    {
        self.compositor = compositor;
    }
    return self;
}

@end
