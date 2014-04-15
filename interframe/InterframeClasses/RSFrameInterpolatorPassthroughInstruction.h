//
//  RSFrameInterpolatorPassthroughInstruction.h
//  interframe
//
//  Created by Ryan Sullivan on 4/9/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "RSFrameInterpolatorBaseInstruction.h"

@interface RSFrameInterpolatorPassthroughInstruction : RSFrameInterpolatorBaseInstruction

-(id)initWithPassthroughTrackID:(CMPersistentTrackID)track forTimeRange:(CMTimeRange)timeRange;

@end
