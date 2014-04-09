//
//  RSFrameInterpolatorInterpolationInstruction.m
//  interframe
//
//  Created by Ryan Sullivan on 4/9/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSFrameInterpolatorInterpolationInstruction.h"

@interface RSFrameInterpolatorInterpolationInstruction ()

@property (strong, nonatomic) NSArray *requiredSourceTrackIDs;
@property (nonatomic) CMPersistentTrackID priorID, nextID;

@end


@implementation RSFrameInterpolatorInterpolationInstruction

-(id)initWithPriorFrameTrackID:(CMPersistentTrackID)priorID
           andNextFrameTrackID:(CMPersistentTrackID)nextID
                  forTimeRange:(CMTimeRange)timeRange {
    if ((self = [self init]))
    {
        _timeRange = timeRange;
        _priorID = priorID;
        _nextID = nextID;
    }
    return self;
}

/**
 * Getters for protocol
 */

@synthesize timeRange = _timeRange;

-(NSArray *)requiredSourceTrackIDs {
    return @[@(_priorID), @(_nextID)];
}

-(CMPersistentTrackID)passthroughTrackID {
    return kCMPersistentTrackID_Invalid;
}

-(BOOL)containsTweening {
    return NO;
}

-(BOOL)enablePostProcessing {
    return NO;
}

@end
