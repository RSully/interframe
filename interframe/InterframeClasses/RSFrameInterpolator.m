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

@property (strong) AVAsset *inputAsset;
@property (strong) NSURL *outputUrl;
@property (strong) AVAssetExportSession *exportSession;
@property Class<AVVideoCompositing> compositor;

@end


@implementation RSFrameInterpolator

-(id)initWithAsset:(AVAsset *)asset output:(NSURL *)output compositor:(Class<AVVideoCompositing>)compositor {
    if ((self = [self init]))
    {
        self.inputAsset = asset;
        self.outputUrl = output;
        self.compositor = compositor;
    }
    return self;
}


-(AVMutableComposition *)buildComposition {

    AVMutableComposition *outputComposition = [AVMutableComposition composition];

    /*
     * Handle prepping composition
     */

    NSMutableArray *inputVideoTracks = [NSMutableArray array];

    // Copy any tracks that aren't video
    for (AVAssetTrack *inputTrack in self.inputAsset.tracks)
    {
        if ([inputTrack.mediaType isEqualToString:AVMediaTypeVideo])
        {
            [inputVideoTracks addObject:inputTrack];
            continue;
        }

        AVMutableCompositionTrack *outputTrack = [outputComposition addMutableTrackWithMediaType:inputTrack.mediaType preferredTrackID:inputTrack.trackID];

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

    return outputComposition;
}

-(AVMutableVideoComposition *)buildVideoCompositionForComposition:(AVMutableComposition*)composition
                                                    andVideoTrack:(AVAssetTrack *)inputVideoTrack {

    /**
     * Metadata
     */

    // Calculate input metadata
    Float64 inputDuration = CMTimeGetSeconds(inputVideoTrack.timeRange.duration);
    Float64 inputFPS = inputVideoTrack.nominalFrameRate;
    NSUInteger inputFrameCount = round(inputFPS * inputDuration);
    Float64 inputFrameDurationSeconds = 1.0 / inputFPS;
//    CMTime inputFrameDuration = CMTimeMakeWithSeconds(inputFrameDurationSeconds, kRSDurationResolution);

    // Calculate expected output metadata
    NSUInteger outputFrameCount = (inputFrameCount * 2) - 1;
    Float64 outputFPS = outputFrameCount / inputDuration;
    Float64 outputFrameDurationSeconds = 1.0 / outputFPS;
    CMTime outputFrameDuration = CMTimeMakeWithSeconds(outputFrameDurationSeconds, kRSDurationResolution);

    CMTimeShow(outputFrameDuration);
    NSLog(@"inputDuration: %f, inputFrameDuration = %f, inputFPS: %f, inputFrameCount: %lu", inputDuration, inputFrameDurationSeconds, inputFPS, inputFrameCount);
    NSLog(@"outputDuration: %f, outputFrameDuration = %f, outputFPS: %f, outputFrameCount: %lu", outputFrameDurationSeconds * outputFrameCount, outputFrameDurationSeconds, outputFPS, outputFrameCount);


    /**
     * Video composition
     */

    AVMutableVideoComposition *outputVideoComposition = [AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:inputVideoTrack.asset];
    outputVideoComposition.customVideoCompositorClass = self.compositor;
    outputVideoComposition.frameDuration = outputFrameDuration;

    /**
     * Create video tracks
     */

    NSError *err = nil;
    AVMutableCompositionTrack *compositionVideoTrackPrior, *compositionVideoTrackNext, *compositionVideoTrackOrigin;

    compositionVideoTrackPrior = [composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                          preferredTrackID:kCMPersistentTrackID_Invalid];
    compositionVideoTrackNext = [composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                         preferredTrackID:kCMPersistentTrackID_Invalid];
    compositionVideoTrackOrigin = [composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                           preferredTrackID:kCMPersistentTrackID_Invalid];

    CMPersistentTrackID originID = compositionVideoTrackOrigin.trackID;
    CMPersistentTrackID nextID = compositionVideoTrackNext.trackID;
    CMPersistentTrackID priorID = compositionVideoTrackPrior.trackID;


    CMTimeRange originTimeRange = inputVideoTrack.timeRange;
    originTimeRange.start = CMTimeConvertScale(originTimeRange.start, kRSDurationResolution, kCMTimeRoundingMethod_Default);
    originTimeRange.duration = CMTimeConvertScale(originTimeRange.duration, kRSDurationResolution, kCMTimeRoundingMethod_Default);

    CMTimeRange nextTimeRange = CMTimeRangeMake(originTimeRange.start, CMTimeSubtract(originTimeRange.duration, outputFrameDuration));
    CMTimeRange priorTimeRange = CMTimeRangeMake(CMTimeAdd(originTimeRange.start, outputFrameDuration), CMTimeSubtract(originTimeRange.duration, outputFrameDuration));

    NSLog(@"DEBUG:");
    CMTimeRangeShow(originTimeRange);
    CMTimeRangeShow(nextTimeRange);
    CMTimeRangeShow(priorTimeRange);



    /*
     * Handle creating timeranges and instructions for output
     */


    NSMutableArray *instructions = [NSMutableArray arrayWithCapacity:outputFrameCount];

    for (NSUInteger frame = 0; frame < inputFrameCount; frame++)
    {
        @autoreleasepool {
            NSLog(@"frame %lu", frame);

            NSUInteger frameOutput = frame * 2;
            CMTimeRange timeRangeInput = CMTimeRangeMake(CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(frame / inputFPS, kRSDurationResolution)), outputFrameDuration);


            // write to origin
            CMTime time = CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(frameOutput / outputFPS, kRSDurationResolution));
            [compositionVideoTrackOrigin insertTimeRange:timeRangeInput ofTrack:inputVideoTrack atTime:time error:&err];

            CMTimeRange timeRange = CMTimeRangeMake(time, outputFrameDuration);
            [instructions addObject:[[RSFrameInterpolatorPassthroughInstruction alloc] initWithPassthroughTrackID:originID
                                                                                                     forTimeRange:timeRange]];


            // if not last, write to next
            if (frame + 1 < inputFrameCount)
            {
                NSUInteger frameNextOutput = frameOutput + 1;
                time = CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(frameNextOutput / outputFPS, kRSDurationResolution));

                [compositionVideoTrackNext insertTimeRange:timeRangeInput ofTrack:inputVideoTrack atTime:time error:&err];
                if (err) NSLog(@"error %@", err);
            }


            // if not first, write to prior
            if (frame > 0)
            {
                NSUInteger framePriorOutput = frameOutput - 1;
                time = CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(framePriorOutput / outputFPS, kRSDurationResolution));

                [compositionVideoTrackPrior insertTimeRange:timeRangeInput ofTrack:inputVideoTrack atTime:time error:&err];
                if (err) NSLog(@"error %@", err);


                // We'll be responsible for adding the interpolation instruction here
                timeRange = CMTimeRangeMake(time, outputFrameDuration);
                [instructions addObject:[[RSFrameInterpolatorInterpolationInstruction alloc] initWithPriorFrameTrackID:nextID
                                                                                                   andNextFrameTrackID:priorID
                                                                                                          forTimeRange:timeRange]];
            }

        }
    }



    NSLog(@"Debug later");
    CMTimeRangeShow(compositionVideoTrackOrigin.timeRange);
    CMTimeRangeShow(compositionVideoTrackNext.timeRange);
    CMTimeRangeShow(compositionVideoTrackPrior.timeRange);


    // Add the instructions
    outputVideoComposition.instructions = instructions;

    return outputVideoComposition;
}


-(void)interpolate {

    AVAssetTrack *videoTrack = [self.inputAsset tracksWithMediaType:AVMediaTypeVideo][0];

    AVMutableComposition *outputComposition = [self buildComposition];
    AVMutableVideoComposition *outputVideoComposition = [self buildVideoCompositionForComposition:outputComposition
                                                                                    andVideoTrack:videoTrack];
    NSLog(@"Built composition!");


//    NSLog(@"%@", [AVAssetExportSession exportPresetsCompatibleWithAsset:self.outputComposition]);

    self.exportSession = [[AVAssetExportSession alloc] initWithAsset:outputComposition
                                                          presetName:AVAssetExportPresetAppleM4VWiFi];
    self.exportSession.videoComposition = outputVideoComposition;

    self.exportSession.outputFileType = CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)self.outputUrl.pathExtension, NULL));
    self.exportSession.outputURL = self.outputUrl;

    NSLog(@"Begin export");

    [self.exportSession exportAsynchronouslyWithCompletionHandler:^{
        NSLog(@"Export completion, %ld", self.exportSession.status);
        NSLog(@"%@, %@", self.exportSession, outputVideoComposition);
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
