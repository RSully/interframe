//
//  RSFrameInterpolatorBaseInstruction.m
//  interframe
//
//  Created by Ryan Sullivan on 4/9/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSFrameInterpolatorBaseInstruction.h"

@implementation RSFrameInterpolatorBaseInstruction

-(BOOL)enablePostProcessing {
    return NO;
}

-(BOOL)containsTweening {
    return NO;
}

-(CMPersistentTrackID)passthroughTrackID {
    return kCMPersistentTrackID_Invalid;
}

-(NSArray *)requiredSourceTrackIDs {
    return @[];
}

-(CMTimeRange)timeRange {
    return kCMTimeRangeInvalid;
}


+(NSString *)descriptionOfTime:(CMTime)time {
    return [NSString stringWithFormat:@"%f", CMTimeGetSeconds(time)];
}
-(NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p, enablePostProcessing = %d, containsTweening = %d, passthroughTrackID = %d, requiredSourceTrackIDs = %@, timeRange = <start = %@, duration = %@>>",
            NSStringFromClass([self class]),
            self,
            self.enablePostProcessing,
            self.containsTweening,
            self.passthroughTrackID,
            self.requiredSourceTrackIDs,
            [[self class] descriptionOfTime:self.timeRange.start],
            [[self class] descriptionOfTime:self.timeRange.duration]];
}

@end
