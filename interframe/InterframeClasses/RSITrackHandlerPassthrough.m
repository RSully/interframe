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
    if ((self = [self _initWithInputTrack:inputTrack readerSettings:nil writerSettings:nil]))
    {
        self.readerOutput.alwaysCopiesSampleData = NO;
    }
    return self;
}

-(void)_mediaDataRequested {
    CMSampleBufferRef sampleBuffer = [self.readerOutput copyNextSampleBuffer];

    if (!sampleBuffer)
    {
        [self markAsFinished];
        return;
    }

    [self.writerInput appendSampleBuffer:sampleBuffer];
    CFRelease(sampleBuffer);
}

@end
