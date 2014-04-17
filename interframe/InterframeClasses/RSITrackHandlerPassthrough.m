//
//  RSITrackHandlerPassthrough.m
//  interframe
//
//  Created by Ryan Sullivan on 4/17/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSITrackHandlerPassthrough.h"

@implementation RSITrackHandlerPassthrough

-(id)initWithInputTrack:(AVAssetTrack *)inputTrack {
    if ((self = [self init]))
    {
        self.readerOutput.alwaysCopiesSampleData = NO;
    }
    return self;
}

@end
