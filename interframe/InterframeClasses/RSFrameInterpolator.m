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




    // Test create origin track only with 1 instruction:
    for (NSUInteger frame = 0; frame < inputFrameCount; frame++)
    {
        @autoreleasepool {

            NSUInteger frameOutput = frame * 2;
            NSLog(@"frame %lu (%lu)", frame, frameOutput);

            CMTime timeInput = CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(frame / inputFPS, kRSDurationResolution));
            CMTimeRange timeRangeInput = CMTimeRangeMake(timeInput, inputFrameDuration);
            CMTime time = CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(frameOutput / outputFPS, kRSDurationResolution));

            [compositionVideoTrackOrigin insertTimeRange:timeRangeInput ofTrack:inputVideoTrack atTime:time error:&err];
            if (err) NSLog(@"error %@", err);
            [compositionVideoTrackOrigin scaleTimeRange:CMTimeRangeMake(time, inputFrameDuration) toDuration:outputFrameDuration];
        }
    }
    CMTimeRangeShow(compositionVideoTrackOrigin.timeRange);
    RSFrameInterpolatorPassthroughInstruction *ins = [[RSFrameInterpolatorPassthroughInstruction alloc] initWithPassthroughTrackID:originID forTimeRange:originTimeRange];
    outputVideoComposition.instructions = @[ins];
    NSLog(@"%@", compositionVideoTrackOrigin.segments);
    NSLog(@"%@", outputVideoComposition.instructions);
    return outputVideoComposition;




    /*
     * Handle creating timeranges and instructions for output
     */


    NSMutableArray *instructions = [NSMutableArray arrayWithCapacity:outputFrameCount];


    for (NSUInteger frame = 0; frame < inputFrameCount; frame++)
    {
        @autoreleasepool {

            NSUInteger frameOutput = frame * 2;
            NSLog(@"frame %lu (%lu)", frame, frameOutput);

            CMTime timeInput = CMTimeAdd(originTimeRange.start, CMTimeMakeWithSeconds(frame / inputFPS, kRSDurationResolution));
            CMTimeRange timeRangeInput = CMTimeRangeMake(timeInput, inputFrameDuration);

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




    // Test instructions for video composition using created tracks:
//    CMTime peM2 = CMTimeSubtract(CMTimeSubtract(CMTimeAdd(originTimeRange.start, originTimeRange.duration), outputFrameDuration), outputFrameDuration);
//    CMTimeRange insAtr = CMTimeRangeMake(originTimeRange.start, peM2);
//    CMTimeRange insBtr = CMTimeRangeMake(peM2, outputFrameDuration);
//    CMTimeRange insCtr = CMTimeRangeMake(CMTimeAdd(peM2, outputFrameDuration), outputFrameDuration);
//    CMTimeRangeShow(insAtr);
//    CMTimeRangeShow(insBtr);
//    RSFrameInterpolatorPassthroughInstruction *insA = [[RSFrameInterpolatorPassthroughInstruction alloc] initWithPassthroughTrackID:originID
//                                                                                                                       forTimeRange:insAtr];
//    RSFrameInterpolatorInterpolationInstruction *insB = [[RSFrameInterpolatorInterpolationInstruction alloc] initWithPriorFrameTrackID:priorID
//                                                                                                                   andNextFrameTrackID:nextID
//                                                                                                                          forTimeRange:insBtr];
//    RSFrameInterpolatorPassthroughInstruction *insC = [[RSFrameInterpolatorPassthroughInstruction alloc] initWithPassthroughTrackID:originID
//                                                                                                                       forTimeRange:insCtr];
//    outputVideoComposition.instructions = @[insA, insB, insC];
//    return outputVideoComposition;



    // Add the instructions
    outputVideoComposition.instructions = instructions;

    return outputVideoComposition;
}


-(void)interpolate {

    AVAssetTrack *videoTrack = [self.inputAsset tracksWithMediaType:AVMediaTypeVideo][0];

    AVMutableComposition *outputComposition = [self buildComposition];
    NSLog(@"Built composition!");
    AVMutableVideoComposition *outputVideoComposition = [self buildVideoCompositionForComposition:outputComposition
                                                                                    andVideoTrack:videoTrack];
    NSLog(@"Built video composition!");

    BOOL valid = [outputVideoComposition isValidForAsset:outputComposition timeRange:CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity) validationDelegate:self];
    NSLog(@"checked validity: %d", valid);


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


#pragma mark - AVVideoCompositionValidationHandling delegate methods


/*!
 @method		videoComposition:shouldContinueValidatingAfterFindingInvalidValueForKey:
 @abstract
 Invoked by an instance of AVVideoComposition when validating an instance of AVVideoComposition, to report a key that has an invalid value.
 @result
 An indication of whether the AVVideoComposition should continue validation in order to report additional problems that may exist.
 */
- (BOOL)videoComposition:(AVVideoComposition *)videoComposition shouldContinueValidatingAfterFindingInvalidValueForKey:(NSString *)key {
    NSLog(@"invalid value for key: %@", key);
    return YES;
}

/*!
 @method		videoComposition:shouldContinueValidatingAfterFindingEmptyTimeRange:
 @abstract
 Invoked by an instance of AVVideoComposition when validating an instance of AVVideoComposition, to report a timeRange that has no corresponding video composition instruction.
 @result
 An indication of whether the AVVideoComposition should continue validation in order to report additional problems that may exist.
 */
- (BOOL)videoComposition:(AVVideoComposition *)videoComposition shouldContinueValidatingAfterFindingEmptyTimeRange:(CMTimeRange)timeRange {
    NSLog(@"empty time range: %f, %f", CMTimeGetSeconds(timeRange.start), CMTimeGetSeconds(timeRange.duration));
    return YES;
}

/*!
 @method		videoComposition:shouldContinueValidatingAfterFindingInvalidTimeRangeInInstruction:
 @abstract
 Invoked by an instance of AVVideoComposition when validating an instance of AVVideoComposition, to report a video composition instruction with a timeRange that's invalid, that overlaps with the timeRange of a prior instruction, or that contains times earlier than the timeRange of a prior instruction.
 @discussion
 Use CMTIMERANGE_IS_INVALID, defined in CMTimeRange.h, to test whether the timeRange itself is invalid. Refer to headerdoc for AVVideoComposition.instructions for a discussion of how timeRanges for instructions must be formulated.
 @result
 An indication of whether the AVVideoComposition should continue validation in order to report additional problems that may exist.
 */
- (BOOL)videoComposition:(AVVideoComposition *)videoComposition shouldContinueValidatingAfterFindingInvalidTimeRangeInInstruction:(id<AVVideoCompositionInstruction>)videoCompositionInstruction {
    NSLog(@"invalid time range in instruction: %@", videoCompositionInstruction);
    return YES;
}

/*!
 @method		videoComposition:shouldContinueValidatingAfterFindingInvalidTrackIDInInstruction:layerInstruction:asset:
 @abstract
 Invoked by an instance of AVVideoComposition when validating an instance of AVVideoComposition, to report a video composition layer instruction with a trackID that does not correspond either to the trackID used for the composition's animationTool or to a track of the asset specified in -[AVVideoComposition isValidForAsset:timeRange:delegate:].
 @result
 An indication of whether the AVVideoComposition should continue validation in order to report additional problems that may exist.
 */
- (BOOL)videoComposition:(AVVideoComposition *)videoComposition shouldContinueValidatingAfterFindingInvalidTrackIDInInstruction:(id<AVVideoCompositionInstruction>)videoCompositionInstruction layerInstruction:(AVVideoCompositionLayerInstruction *)layerInstruction asset:(AVAsset *)asset {
    NSLog(@"invalid trackID in instruction: %@, %@, %@", videoCompositionInstruction, layerInstruction, asset);
    return YES;
}

@end
