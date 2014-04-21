//
//  RSITrackHandlerPassthrough.h
//  interframe
//
//  Created by Ryan Sullivan on 4/17/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSITrackHandler.h"

@interface RSITrackHandlerPassthrough : RSITrackHandler

-(id)initWithInputTrack:(AVAssetTrack *)inputTrack;

@end
