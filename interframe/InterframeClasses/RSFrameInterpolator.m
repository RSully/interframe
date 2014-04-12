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
    CMTime inputFrameDuration = CMTimeMakeWithSeconds(inputFrameDurationSeconds, kRSDurationResolution);

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


    NSLog(@"DEBUG:");
    CMTimeRangeShow(originTimeRange);


    /**
     * Copy stream and re-time
     */


//    for (NSUInteger frame = 0; frame < inputFrameCount; frame++)
//    {
//        NSUInteger frameOutput = frame * 2;
//
//
//        CMTime timeInput = CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(frame / inputFPS, kRSDurationResolution));
//        CMTimeRange timeRangeInput = CMTimeRangeMake(timeInput, inputFrameDuration);
//
//        CMTime timeOutput = CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(frameOutput / outputFPS, kRSDurationResolution));
//
//
//        [compositionVideoTrackOrigin insertTimeRange:timeRangeInput ofTrack:inputVideoTrack atTime:timeOutput error:&err];
//        if (err) NSLog(@"error: %@", err);
//
//        [compositionVideoTrackOrigin scaleTimeRange:CMTimeRangeMake(timeOutput, inputFrameDuration) toDuration:outputFrameDuration];
//
//
////        // if not first, remove prior
////        if (frame > 0)
////        {
////            NSUInteger framePriorOutput = frameOutput - 1;
////            CMTimeRange timeRangePrior = CMTimeRangeMake(CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(framePriorOutput / outputFPS, kRSDurationResolution)), outputFrameDuration);
////
//////            [compositionVideoTrackOrigin removeTimeRange:timeRangePrior];
//////            [compositionVideoTrackOrigin insertEmptyTimeRange:timeRangePrior];
////        }
////
////        // if not last, add empty
////        if (frame + 1 < inputFrameCount)
////        {
////            NSUInteger frameNextOutput = frameOutput + 1;
////            CMTimeRange timeRangeNext = CMTimeRangeMake(CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(frameNextOutput / outputFPS, kRSDurationResolution)), outputFrameDuration);
////
//////            [compositionVideoTrackOrigin removeTimeRange:timeRangeNext];
//////            [compositionVideoTrackOrigin insertEmptyTimeRange:timeRangeNext];
////        }
//    }
//
//    NSLog(@"%@", compositionVideoTrackOrigin.segments);
//    exit(1);

    /*
     * Handle creating timeranges and instructions for output
     */


    NSMutableArray *instructions = [NSMutableArray arrayWithCapacity:outputFrameCount];


    for (NSUInteger frame = 0; frame < inputFrameCount; frame++)
    {
        @autoreleasepool {

            NSUInteger frameOutput = frame * 2;
            CMTimeRange timeRangeInput = CMTimeRangeMake(CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(frame / inputFPS, kRSDurationResolution)), inputFrameDuration);
            NSLog(@"frame %lu (%lu)", frame, frameOutput);

            CMTime time;
            CMTimeRange timeRange;


            // if not first, write to next
            if (frame > 0)
            {
                NSUInteger framePriorOutput = frameOutput - 1;
                time = CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(framePriorOutput / outputFPS, kRSDurationResolution));

                [compositionVideoTrackNext insertTimeRange:timeRangeInput ofTrack:inputVideoTrack atTime:time error:&err];
                if (err) NSLog(@"error %@", err);
                [compositionVideoTrackNext scaleTimeRange:CMTimeRangeMake(time, inputFrameDuration) toDuration:outputFrameDuration];


                // We'll be responsible for adding the interpolation instruction here
                timeRange = CMTimeRangeMake(time, outputFrameDuration);
                [instructions addObject:[[RSFrameInterpolatorInterpolationInstruction alloc] initWithPriorFrameTrackID:priorID
                                                                                                   andNextFrameTrackID:nextID
                                                                                                          forTimeRange:timeRange]];
            }


            // write to origin
            {
                time = CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(frameOutput / outputFPS, kRSDurationResolution));
                [compositionVideoTrackOrigin insertTimeRange:timeRangeInput ofTrack:inputVideoTrack atTime:time error:&err];
                if (err) NSLog(@"error %@", err);
                [compositionVideoTrackOrigin scaleTimeRange:CMTimeRangeMake(time, inputFrameDuration) toDuration:outputFrameDuration];

                timeRange = CMTimeRangeMake(time, outputFrameDuration);
                [instructions addObject:[[RSFrameInterpolatorPassthroughInstruction alloc] initWithPassthroughTrackID:originID
                                                                                                         forTimeRange:timeRange]];
            }


            // if not last, write to prior
            if (frame + 1 < inputFrameCount)
            {
                NSUInteger frameNextOutput = frameOutput + 1;
                time = CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(frameNextOutput / outputFPS, kRSDurationResolution));

                [compositionVideoTrackPrior insertTimeRange:timeRangeInput ofTrack:inputVideoTrack atTime:time error:&err];
                if (err) NSLog(@"error %@", err);
                [compositionVideoTrackPrior scaleTimeRange:CMTimeRangeMake(time, inputFrameDuration) toDuration:outputFrameDuration];
            }

        }
    }


//    NSLog(@"INS TEST:");
//    CMTime peM2 = CMTimeSubtract(CMTimeSubtract(CMTimeAdd(originTimeRange.start, originTimeRange.duration), outputFrameDuration), outputFrameDuration);
//    CMTimeRange insAtr = CMTimeRangeMake(originTimeRange.start, peM2);
//    CMTimeRange insBtr = CMTimeRangeMake(peM2, CMTimeAdd(outputFrameDuration, outputFrameDuration));
//    CMTimeRangeShow(insAtr);
//    CMTimeRangeShow(insBtr);
//    RSFrameInterpolatorPassthroughInstruction *insA = [[RSFrameInterpolatorPassthroughInstruction alloc] initWithPassthroughTrackID:originID
//                                                                                                                       forTimeRange:insAtr];
//    RSFrameInterpolatorInterpolationInstruction *insB = [[RSFrameInterpolatorInterpolationInstruction alloc] initWithPriorFrameTrackID:priorID
//                                                                                                                   andNextFrameTrackID:nextID
//                                                                                                                          forTimeRange:insBtr];
//    outputVideoComposition.instructions = @[insA, insB];
//    return outputVideoComposition;


//    NSLog(@"Debug later");
//    NSLog(@"%@", instructions);
//    CMTimeRangeShow(compositionVideoTrackOrigin.timeRange);
//    NSLog(@"%@", compositionVideoTrackOrigin.segments);
//    CMTimeRangeShow(compositionVideoTrackNext.timeRange);
//    NSLog(@"%@", compositionVideoTrackNext.segments);
//    CMTimeRangeShow(compositionVideoTrackPrior.timeRange);
//    NSLog(@"%@", compositionVideoTrackPrior.segments);


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
