//
//  RSITrackHandler.m
//  interframe
//
//  Created by Ryan Sullivan on 4/17/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSITrackHandler.h"

@interface RSITrackHandler ()
@property dispatch_queue_t mediaQueue;
@property BOOL isFinished;
/*
 * Make these non-readonly
 */
@property (strong) AVAssetTrack *inputTrack;
@property (strong) AVAssetReaderOutput *readerOutput;
@property (strong) AVAssetWriterInput *writerInput;
@end

@implementation RSITrackHandler

-(id)init
{
    if ((self = [super init]))
    {
        self.mediaQueue = dispatch_queue_create("me.rsullivan.apps.interframe.trackHandlerMediaQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

-(id)_initWithInputTrack:(AVAssetTrack *)inputTrack readerSettings:(NSDictionary *)readerSettings writerSettings:(NSDictionary *)writerSettings
{
    if ((self = [self init]))
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

-(void)markAsFinished
{
    [self.writerInput markAsFinished];
    self.isFinished = YES;
}

-(void)startHandlingWithCompletionHandler:(void (^)(void))completionHandler {
    [self.writerInput requestMediaDataWhenReadyOnQueue:self.mediaQueue usingBlock:^{
        if (self.isFinished)
        {
            return;
        }

        @autoreleasepool {
            [self _mediaDataRequested];
        }

        if (self.isFinished)
        {
            dispatch_async(dispatch_get_main_queue(), completionHandler);
        }
    }];
}

-(void)_mediaDataRequested {}

@end
