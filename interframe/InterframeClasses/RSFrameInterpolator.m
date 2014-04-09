//
//  RSUpconverter.m
//  interframe
//
//  Created by Ryan Sullivan on 4/7/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSFrameInterpolator.h"
#import "RSFrameInterpolatorPassthroughInstruction.h"
#import "RSFrameInterpolatorInterpolationInstruction.h"

//#define kRSDurationResolution 600
#define kRSDurationResolution NSEC_PER_SEC

@interface RSFrameInterpolator ()

@property (strong) NSMutableDictionary *defaultPixelSettings;

// Input assets
@property (strong) AVAsset *inputAsset;
@property (strong) AVAssetTrack *inputAssetVideoTrack;
// Input metadata
@property float inputFPS;
@property NSUInteger inputFrameCount;

// Output composition
@property (strong) AVMutableComposition *outputComposition;
@property (strong) AVMutableVideoComposition *outputVideoComposition;
// Output metadata
@property float outputFPS;
@property NSUInteger outputFrameCount;

// Export stuff
@property (strong) NSURL *outputUrl;
@property (strong) AVAssetExportSession *exportSession;

@end


@implementation RSFrameInterpolator

-(id)initWithAsset:(AVAsset *)asset output:(NSURL *)output {
    if ((self = [self init]))
    {
        self.inputAsset = asset;
        self.outputUrl = output;


        // Setup input metadata
        self.inputAssetVideoTrack = [self.inputAsset tracksWithMediaType:AVMediaTypeVideo][0];
        Float64 inputDuration = CMTimeGetSeconds(self.inputAssetVideoTrack.timeRange.duration);
        self.inputFPS = self.inputAssetVideoTrack.nominalFrameRate;
        self.inputFrameCount = round(self.inputFPS * inputDuration);

        // Calculate expected output metadata
        self.outputFrameCount = (self.inputFrameCount * 2.0) - 1;
        self.outputFPS = self.outputFrameCount / inputDuration;


        self.outputComposition = [AVMutableComposition composition];
        self.outputVideoComposition = [AVMutableVideoComposition videoComposition];
        self.outputVideoComposition.renderSize = self.inputAssetVideoTrack.naturalSize;
        self.outputVideoComposition.frameDuration = CMTimeMakeWithSeconds(1.0 / self.outputFPS, kRSDurationResolution);

        NSLog(@"Input of %f seconds", inputDuration);
        CMTimeRangeShow(self.inputAssetVideoTrack.timeRange);
    }
    return self;
}

-(void)setCompositor:(Class<RSFrameInterpolatorCompositor>)compositor {
    NSLog(@"Set compositor");
    self.outputVideoComposition.customVideoCompositorClass = compositor;
}


-(void)buildComposition {
    CMTime frameDuration = self.outputVideoComposition.frameDuration;

    /*
     * Handle prepping composition
     */

    NSMutableArray *inputVideoTracks = [NSMutableArray array];

    NSLog(@"Copying non-video tracks to outputComposition");
    // Copy any tracks that aren't video
    for (AVAssetTrack *inputTrack in self.inputAsset.tracks)
    {
        if ([inputTrack.mediaType isEqualToString:AVMediaTypeVideo])
        {
            [inputVideoTracks addObject:inputTrack];
            continue;
        }

        AVMutableCompositionTrack *outputTrack = [self.outputComposition addMutableTrackWithMediaType:inputTrack.mediaType preferredTrackID:inputTrack.trackID];

        NSError *err = nil;
        [outputTrack insertTimeRange:inputTrack.timeRange
                             ofTrack:inputTrack
                              atTime:inputTrack.timeRange.start
                               error:&err];
        if (err)
        {
            NSLog(@"Failed to copy track %@ into output composition", inputTrack);
        }
    }

    if (inputVideoTracks.count > 1)
    {
        // TODO: eventually we could handle any number of input video tracks
        NSLog(@"*** Bailing, we have more than 1 input video track");
        return;
    }

    AVCompositionTrack *inputVideoTrack = inputVideoTracks[0];

    NSError *err = nil;
    AVMutableCompositionTrack *compositionVideoTracks[2];
    compositionVideoTracks[0] = [self.outputComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                    preferredTrackID:kCMPersistentTrackID_Invalid];
    compositionVideoTracks[1] = [self.outputComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                    preferredTrackID:kCMPersistentTrackID_Invalid];
    CMPersistentTrackID priorID = compositionVideoTracks[0].trackID;
    CMPersistentTrackID nextID = compositionVideoTracks[1].trackID;

    CMTime priorStartTime = inputVideoTrack.timeRange.start;
    CMTime nextStartTime = CMTimeAdd(priorStartTime, frameDuration);

    [compositionVideoTracks[0] insertTimeRange:inputVideoTrack.timeRange
                                       ofTrack:inputVideoTrack
                                        atTime:priorStartTime
                                         error:&err];
    if (err)
    {
        NSLog(@"** Failed to insert prior video track into output composition");
        return;
    }
    [compositionVideoTracks[1] insertTimeRange:inputVideoTrack.timeRange
                                       ofTrack:inputVideoTrack
                                        atTime:nextStartTime
                                         error:&err];
    if (err)
    {
        NSLog(@"** Failed to insert next video track into output composition");
        return;
    }

    /*
     * Handle creating timeranges and instructions for output
     */

    // Only 1 frame comes from prior
    CMTimeRange *passthroughTimeRangesPrior = alloca(sizeof(CMTimeRange) * 1);
    // The rest of the source frames come from next
    CMTimeRange *passthroughTimeRangesNext = alloca(sizeof(CMTimeRange) * (self.inputFrameCount - 1));
    // Everything else from inbetween
    CMTimeRange *inbetweenTimeRanges = alloca(sizeof(CMTimeRange) * (self.inputFrameCount - 1));

    CMTime startTime = priorStartTime;

    // Handle all timeranges
    {
        // Handle prior:
        {
            passthroughTimeRangesPrior[0] = CMTimeRangeMake(startTime, frameDuration);
        }
        for (NSUInteger frame = 2, i = 0; frame <= self.outputFrameCount; frame += 2, i++)
        {
            startTime = CMTimeMakeWithSeconds((frame - 1) / self.outputFPS, kRSDurationResolution);
            inbetweenTimeRanges[i] = CMTimeRangeMake(CMTimeAdd(priorStartTime, startTime), frameDuration);

            startTime = CMTimeMakeWithSeconds((frame) / self.outputFPS, kRSDurationResolution);
            passthroughTimeRangesNext[i] = CMTimeRangeMake(CMTimeAdd(priorStartTime, startTime), frameDuration);
        }
    }

    NSMutableArray *instructions = [NSMutableArray arrayWithCapacity:self.outputFrameCount];
    RSFrameInterpolatorPassthroughInstruction *instructionPassthrough;
    RSFrameInterpolatorInterpolationInstruction *instructionInbetween;

    // Handle all instructions
    {
        // Handle prior
        {
            instructionPassthrough = [[RSFrameInterpolatorPassthroughInstruction alloc] initWithPassthroughTrackID:priorID forTimeRange:passthroughTimeRangesPrior[0]];
            [instructions addObject:instructionPassthrough];
            NSLog(@"%@", instructionPassthrough);
        }

        for (NSUInteger frame = 2, i = 0; frame <= self.outputFrameCount; frame += 2, i++)
        {
            instructionInbetween = [[RSFrameInterpolatorInterpolationInstruction alloc] initWithPriorFrameTrackID:priorID andNextFrameTrackID:nextID forTimeRange:inbetweenTimeRanges[i]];
            instructionPassthrough = [[RSFrameInterpolatorPassthroughInstruction alloc] initWithPassthroughTrackID:nextID forTimeRange:passthroughTimeRangesNext[i]];

            [instructions addObject:instructionInbetween];
            [instructions addObject:instructionPassthrough];

            NSLog(@"%@", instructionInbetween);
            NSLog(@"%@", instructionPassthrough);
        }
    }

    // Add the instructions
    self.outputVideoComposition.instructions = instructions;
}

-(void)interpolate {
    [self buildComposition];
    NSLog(@"Built composition!");


//    NSLog(@"%@", [AVAssetExportSession exportPresetsCompatibleWithAsset:self.outputComposition]);

    self.exportSession = [[AVAssetExportSession alloc] initWithAsset:self.outputComposition
                                                          presetName:AVAssetExportPresetAppleM4VWiFi];
    self.exportSession.videoComposition = self.outputVideoComposition;

    self.exportSession.outputFileType = CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)self.outputUrl.pathExtension, NULL));
    self.exportSession.outputURL = self.outputUrl;


    [self.exportSession exportAsynchronouslyWithCompletionHandler:^{
        NSLog(@"Export completion, %ld", self.exportSession.status);
        NSLog(@"%@, %@", self.exportSession, self.outputVideoComposition);
        switch (self.exportSession.status)
        {
            case AVAssetExportSessionStatusCancelled:
                NSLog(@".. canceled");
                break;
            case AVAssetExportSessionStatusFailed:
                NSLog(@".. failed: %@", self.exportSession.error);
                break;
        }

        [self.delegate interpolatorFinished:self];
    }];
}

@end
