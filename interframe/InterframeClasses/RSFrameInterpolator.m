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


//    [compositionVideoTrackOrigin insertTimeRange:originTimeRange
//                                         ofTrack:inputVideoTrack
//                                          atTime:originTimeRange.start
//                                           error:&err];
//    if (err)
//    {
//        NSLog(@"** Failed to insert origin video track into output composition: %@", err);
//    }
//
//    [compositionVideoTrackNext insertTimeRange:nextTimeRange
//                                       ofTrack:inputVideoTrack
//                                        atTime:CMTimeAdd(originTimeRange.start, outputFrameDuration)
//                                         error:&err];
//    if (err)
//    {
//        NSLog(@"** Failed to insert next video track into output composition: %@", err);
//        return nil;
//    }
//
//    [compositionVideoTrackPrior insertTimeRange:priorTimeRange
//                                        ofTrack:inputVideoTrack
//                                         atTime:originTimeRange.start
//                                          error:&err];
//    if (err)
//    {
//        NSLog(@"** Failed to insert prior video track into output composition: %@", err);
//        return nil;
//    }



    /*
     * Handle creating timeranges and instructions for output
     */


    NSMutableArray *instructions = [NSMutableArray arrayWithCapacity:outputFrameCount];

    // expr         explain                 output      input
    // -----------------------------------------------------------
    // frame - 2 = first source frame   // 0 2 4    // 0 1 2
    // frame - 1 = inbetween frame      // 1 3 5    //
    // frame - 0 = last source frame    // 2 4 6    // 1 2 3
    // -----------------------------------------------------------
    for (NSUInteger frame = 2; frame < outputFrameCount; frame += 2)
    {
        @autoreleasepool {
            NSUInteger framePrior, frameInbetween, frameNext;
            CMTime timePrior, timeInbetween, timeNext;
            CMTimeRange timeRangePrior, timeRangeInbetween, timeRangeNext;

            NSUInteger framePriorInput, frameNextInput;
            CMTime timePriorInput, timeNextInput;
            CMTimeRange timeRangePriorInput, timeRangeNextInput;

            framePrior = frame - 2;
            frameInbetween = frame - 1;
            frameNext = frame;

            timePrior = CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(framePrior / outputFPS, kRSDurationResolution));
            timeInbetween = CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(frameInbetween / outputFPS, kRSDurationResolution));
            timeNext = CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(frameNext / outputFPS, kRSDurationResolution));

            timeRangePrior = CMTimeRangeMake(timePrior, outputFrameDuration);
            timeRangeInbetween = CMTimeRangeMake(timeInbetween, outputFrameDuration);
            timeRangeNext = CMTimeRangeMake(timeNext, outputFrameDuration);


            framePriorInput = framePrior / 2;
            frameNextInput = frameNext / 2;

            timePriorInput = CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(framePriorInput / inputFPS, kRSDurationResolution));
            timeNextInput = CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(frameNextInput / inputFPS, kRSDurationResolution));

            timeRangePriorInput = CMTimeRangeMake(timePriorInput, outputFrameDuration);
            timeRangeNextInput = CMTimeRangeMake(timeNextInput, outputFrameDuration);

            NSLog(@"%lu, %lu, %lu : %lu, %lu", framePrior, frameInbetween, frameNext, framePriorInput, frameNextInput);
            CMTimeRangeShow(timeRangePrior);
            CMTimeRangeShow(timeRangeInbetween);
            CMTimeRangeShow(timeRangeNext);
            CMTimeRangeShow(timeRangePriorInput);
            CMTimeRangeShow(timeRangeNextInput);


            // Handle first frame special
            if (framePrior == 0)
            {
                [compositionVideoTrackOrigin insertTimeRange:timeRangePriorInput ofTrack:inputVideoTrack atTime:timePrior error:&err];
                [instructions addObject:[[RSFrameInterpolatorPassthroughInstruction alloc] initWithPassthroughTrackID:originID
                                                                                                         forTimeRange:timeRangePrior]];
            }


            [compositionVideoTrackNext insertTimeRange:timeRangeNextInput
                                               ofTrack:inputVideoTrack
                                                atTime:timeInbetween
                                                 error:&err];
            [compositionVideoTrackPrior insertTimeRange:timeRangePriorInput
                                                ofTrack:inputVideoTrack
                                                 atTime:timeInbetween
                                                  error:&err];

            [instructions addObject:[[RSFrameInterpolatorInterpolationInstruction alloc] initWithPriorFrameTrackID:nextID
                                                                                               andNextFrameTrackID:priorID
                                                                                                      forTimeRange:timeRangeInbetween]];


            [compositionVideoTrackOrigin insertTimeRange:timeRangeNextInput ofTrack:inputVideoTrack atTime:timeNext error:&err];
            [instructions addObject:[[RSFrameInterpolatorPassthroughInstruction alloc] initWithPassthroughTrackID:originID
                                                                                                     forTimeRange:timeRangeNext]];
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
