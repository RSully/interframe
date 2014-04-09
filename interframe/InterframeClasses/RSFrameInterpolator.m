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

//    CMTime priorStartTime = inputVideoTrack.timeRange.start;
//    CMTime nextStartTime = CMTimeAdd(priorStartTime, frameDuration);
    CMTimeRange priorTimeRange = CMTimeRangeMake(inputVideoTrack.timeRange.start, inputVideoTrack.timeRange.duration);
    CMTime priorEndTime = CMTimeAdd(priorTimeRange.start, inputVideoTrack.timeRange.duration);
    CMTimeRange nextTimeRange = CMTimeRangeMake(CMTimeAdd(priorTimeRange.start, frameDuration), inputVideoTrack.timeRange.duration);

    [compositionVideoTrackPrior insertTimeRange:inputVideoTrack.timeRange
                                        ofTrack:inputVideoTrack
                                         atTime:priorTimeRange.start
                                          error:&err];
    [compositionVideoTrackPrior insertEmptyTimeRange:CMTimeRangeMake(priorEndTime, frameDuration)];
    if (err)
    {
        NSLog(@"** Failed to insert prior video track into output composition: %@", err);
        return;
    }
    [compositionVideoTrackNext insertEmptyTimeRange:CMTimeRangeMake(priorTimeRange.start, frameDuration)];
    [compositionVideoTrackNext insertTimeRange:inputVideoTrack.timeRange
                                       ofTrack:inputVideoTrack
                                        atTime:nextTimeRange.start
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

    NSUInteger framePrior, frameInbetween, frameNext;
    CMTime timePrior, timeInbetween, timeNext;
    CMTimeRange timeRangePrior, timeRangeInbetween, timeRangeNext;

    // Then handle all inbetween+next:
    for (NSUInteger frame = 2; frame < self.outputFrameCount; frame += 2)
    {
        @autoreleasepool {
            framePrior = frame - 2;
            frameInbetween = frame - 1;
            frameNext = frame;

            timePrior = CMTimeAdd(priorTimeRange.start, CMTimeMakeWithSeconds(framePrior / self.outputFPS, kRSDurationResolution));
            timeInbetween = CMTimeAdd(priorTimeRange.start, CMTimeMakeWithSeconds(frameInbetween / self.outputFPS, kRSDurationResolution));
            timeNext = CMTimeAdd(priorTimeRange.start, CMTimeMakeWithSeconds(frameNext / self.outputFPS, kRSDurationResolution));

            timeRangePrior = CMTimeRangeMake(timePrior, frameDuration);
            timeRangeInbetween = CMTimeRangeMake(timeInbetween, frameDuration);
            timeRangeNext = CMTimeRangeMake(timeNext, frameDuration);

            // Handle first frame special
            if (framePrior == 0)
            {
                [instructions addObject:[[RSFrameInterpolatorPassthroughInstruction alloc] initWithPassthroughTrackID:priorID
                                                                                                         forTimeRange:timeRangePrior]];
            }

            [instructions addObject:[[RSFrameInterpolatorInterpolationInstruction alloc] initWithPriorFrameTrackID:priorID
                                                                                               andNextFrameTrackID:nextID
                                                                                                      forTimeRange:timeRangeInbetween]];
            [instructions addObject:[[RSFrameInterpolatorPassthroughInstruction alloc] initWithPassthroughTrackID:nextID
                                                                                                     forTimeRange:timeRangeNext]];
        }
    }


//    RSFrameInterpolatorPassthroughInstruction *insA = [[RSFrameInterpolatorPassthroughInstruction alloc] initWithPassthroughTrackID:priorID forTimeRange:priorTimeRange];
//    RSFrameInterpolatorPassthroughInstruction *insB = [[RSFrameInterpolatorPassthroughInstruction alloc] initWithPassthroughTrackID:nextID forTimeRange:CMTimeRangeMake(priorEndTime, frameDuration)];
//    self.outputVideoComposition.instructions = @[insA, insB];
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
