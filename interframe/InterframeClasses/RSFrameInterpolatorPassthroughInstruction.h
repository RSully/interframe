//
//  RSFrameInterpolatorPassthroughInstruction.h
//  interframe
//
//  Created by Ryan Sullivan on 4/9/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface RSFrameInterpolatorPassthroughInstruction : NSObject <AVVideoCompositionInstruction>

-(id)initWithPassthroughTrackID:(CMPersistentTrackID)track forTimeRange:(CMTimeRange)timeRange;

@end