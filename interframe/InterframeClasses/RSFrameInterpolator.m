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

//#define kRSDurationResolution 300
#define kRSDurationResolution NSEC_PER_SEC
//#define kRSDurationResolution 240

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
@property CMTime outputFrameDuration;
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
        self.outputFrameCount = (self.inputFrameCount * 2) - 1;
        self.outputFPS = self.outputFrameCount / inputDuration;
        self.outputFrameDuration = CMTimeMakeWithSeconds(1.0 / self.outputFPS, kRSDurationResolution);


        self.outputComposition = [AVMutableComposition composition];
        self.outputVideoComposition = [AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:self.inputAsset];
//        self.outputVideoComposition.renderSize = self.inputAssetVideoTrack.naturalSize;
        self.outputVideoComposition.frameDuration = self.outputFrameDuration;

        NSLog(@"Input of %f seconds, %ld frames, %f fps", (self.inputFrameCount / self.inputFPS), self.inputFrameCount, self.inputFPS);
        CMTimeRangeShow(self.inputAssetVideoTrack.timeRange);
        NSLog(@"Output of %f seconds, %ld frames, %f fps", (self.outputFrameCount / self.outputFPS), self.outputFrameCount, self.outputFPS);
    }
    return self;
}

-(void)setCompositor:(Class<RSFrameInterpolatorCompositor>)compositor {
    NSLog(@"-setCompositor");
    self.outputVideoComposition.customVideoCompositorClass = compositor;
}


-(void)buildComposition {
    CMTime frameDuration = self.outputFrameDuration;

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
    AVMutableCompositionTrack *compositionVideoTrackPrior, *compositionVideoTrackNext;
    compositionVideoTrackPrior = [self.outputComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                     preferredTrackID:kCMPersistentTrackID_Invalid];
    compositionVideoTrackNext = [self.outputComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                    preferredTrackID:kCMPersistentTrackID_Invalid];
    CMPersistentTrackID priorID = compositionVideoTrackPrior.trackID;
    CMPersistentTrackID nextID = compositionVideoTrackNext.trackID;

    CMTime priorStartTime = inputVideoTrack.timeRange.start;
    CMTime nextStartTime = CMTimeAdd(priorStartTime, frameDuration);
    CMTimeRange priorTimeRange = inputVideoTrack.timeRange;
    CMTimeRange nextTimeRange = inputVideoTrack.timeRange;
//    CMTimeRange nextTimeRange = CMTimeRangeMake(inputVideoTrack.timeRange.start, CMTimeSubtract(inputVideoTrack.timeRange.duration, frameDuration));

    [compositionVideoTrackPrior insertTimeRange:priorTimeRange
                                        ofTrack:inputVideoTrack
                                         atTime:priorStartTime
                                          error:&err];
    [compositionVideoTrackPrior insertEmptyTimeRange:CMTimeRangeMake(nextStartTime, frameDuration)];
    if (err)
    {
        NSLog(@"** Failed to insert prior video track into output composition: %@", err);
        return;
    }
    [compositionVideoTrackNext insertEmptyTimeRange:CMTimeRangeMake(priorStartTime, frameDuration)];
    [compositionVideoTrackNext insertTimeRange:nextTimeRange
                                       ofTrack:inputVideoTrack
                                        atTime:nextStartTime
                                         error:&err];
    if (err)
    {
        NSLog(@"** Failed to insert next video track into output composition: %@", err);
        return;
    }

    NSLog(@"prior: %d, next: %d", priorID, nextID);


    /*
     * Handle creating timeranges and instructions for output
     */


    NSMutableArray *instructions = [NSMutableArray arrayWithCapacity:self.outputFrameCount];
    RSFrameInterpolatorPassthroughInstruction *instructionPassthrough;
    RSFrameInterpolatorInterpolationInstruction *instructionInbetween;

    CMTime startTime = priorStartTime;

    // Handle all timeranges
    {
        // Handle prior:
        {
            CMTimeRange passthroughTimeRangePrior = CMTimeRangeMake(startTime, frameDuration);
            CMTimeRangeShow(passthroughTimeRangePrior);

            instructionPassthrough = [[RSFrameInterpolatorPassthroughInstruction alloc] initWithPassthroughTrackID:priorID forTimeRange:passthroughTimeRangePrior];

            [instructions addObject:instructionPassthrough];
        }
        for (NSUInteger frame = 2, i = 0; frame < self.outputFrameCount; frame += 2, i++)
        {
            startTime = CMTimeMakeWithSeconds((frame - 1) / self.outputFPS, kRSDurationResolution);
            CMTimeRange inbetweenTimeRange = CMTimeRangeMake(CMTimeAdd(priorStartTime, startTime), frameDuration);

            startTime = CMTimeMakeWithSeconds((frame) / self.outputFPS, kRSDurationResolution);
            CMTimeRange passthroughTimeRangeNext = CMTimeRangeMake(CMTimeAdd(priorStartTime, startTime), frameDuration);


            instructionInbetween = [[RSFrameInterpolatorInterpolationInstruction alloc] initWithPriorFrameTrackID:priorID andNextFrameTrackID:nextID forTimeRange:inbetweenTimeRange];
            instructionPassthrough = [[RSFrameInterpolatorPassthroughInstruction alloc] initWithPassthroughTrackID:nextID forTimeRange:passthroughTimeRangeNext];

            [instructions addObject:instructionInbetween];
            [instructions addObject:instructionPassthrough];

            CMTimeRangeShow(inbetweenTimeRange);
            CMTimeRangeShow(passthroughTimeRangeNext);
        }
    }


//    RSFrameInterpolatorPassthroughInstruction *ins = [[RSFrameInterpolatorPassthroughInstruction alloc] initWithPassthroughTrackID:priorID forTimeRange:inputVideoTrack.timeRange];
//    self.outputVideoComposition.instructions = @[ins];
//    return;

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
