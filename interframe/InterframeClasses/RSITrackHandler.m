//
//  RSITrackHandler.m
//  interframe
//
//  Created by Ryan Sullivan on 4/17/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSITrackHandler.h"

@interface RSITrackHandler ()
/*
 * Make these non-readonly
 */
@property (strong) AVAssetTrack *inputTrack;
@property (strong) AVAssetReaderOutput *readerOutput;
@property (strong) AVAssetWriterInput *writerInput;
@end

@implementation RSITrackHandler

-(id)_initWithInputTrack:(AVAssetTrack *)inputTrack readerSettings:(NSDictionary *)readerSettings writerSettings:(NSDictionary *)writerSettings
{
    if ((self = [super init]))
    {
        self.inputTrack = inputTrack;

        self.readerOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:inputTrack outputSettings:readerSettings];

        // TODO: are there more than 1 format description?
        CMFormatDescriptionRef formatHint = (__bridge CMFormatDescriptionRef)([inputTrack formatDescriptions][0]);

//        self.writerInput = [[AVAssetWriterInput alloc] initWithMediaType:inputTrack.mediaType outputSettings:writerSettings];
        self.writerInput = [[AVAssetWriterInput alloc] initWithMediaType:inputTrack.mediaType outputSettings:writerSettings sourceFormatHint:formatHint];
    }
    return self;
}

@end
