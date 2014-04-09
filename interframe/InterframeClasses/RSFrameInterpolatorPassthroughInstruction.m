//
//  RSFrameInterpolatorPassthroughInstruction.m
//  interframe
//
//  Created by Ryan Sullivan on 4/9/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSFrameInterpolatorPassthroughInstruction.h"


@implementation RSFrameInterpolatorPassthroughInstruction

-(id)initWithPassthroughTrackID:(CMPersistentTrackID)passthroughTrackID forTimeRange:(CMTimeRange)timeRange {
    if ((self = [self init]))
    {
        _passthroughTrackID = passthroughTrackID;
        _timeRange = timeRange;
    }
    return self;
}

/*
 * Getters for protocol
 */

@synthesize passthroughTrackID = _passthroughTrackID;
@synthesize timeRange = _timeRange;

-(NSArray *)requiredSourceTrackIDs {
    return @[@(self.passthroughTrackID)];
}

-(BOOL)enablePostProcessing {
    return NO;
}

-(BOOL)containsTweening {
    return NO;
}

@end
