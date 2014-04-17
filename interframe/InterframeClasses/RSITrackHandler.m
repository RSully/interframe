//
//  RSITrackHandler.m
//  interframe
//
//  Created by Ryan Sullivan on 4/17/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSITrackHandler.h"

@implementation RSITrackHandler

-(id)_initWithInputTrack:(AVAssetTrack *)inputTrack readerSettings:(NSDictionary *)readerSettings writerSettings:(NSDictionary *)writerSettings
{
    if ((self = [super init]))
    {
        self.readerOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:inputTrack outputSettings:readerSettings];

        self.writerInput = [[AVAssetWriterInput alloc] initWithMediaType:inputTrack.mediaType outputSettings:writerSettings];
    }
    return self;
}

@end
