//
//  RSFrameInterpolatorInterpolationInstruction.h
//  interframe
//
//  Created by Ryan Sullivan on 4/9/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface RSFrameInterpolatorInterpolationInstruction : NSObject <AVVideoCompositionInstruction>

-(id)initWithPriorFrameTrackID:(CMPersistentTrackID)priorID
           andNextFrameTrackID:(CMPersistentTrackID)nextID
                  forTimeRange:(CMTimeRange)timeRange;

@property (nonatomic, readonly) CMPersistentTrackID priorID, nextID;

@end
