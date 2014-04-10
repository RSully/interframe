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
@property Class<RSFrameInterpolatorCompositor> compositor;

@end


@implementation RSFrameInterpolator

-(id)initWithAsset:(AVAsset *)asset output:(NSURL *)output compositor:(Class<RSFrameInterpolatorCompositor>)compositor {
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

    NSLog(@"Copying non-video tracks to outputComposition");
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
    float inputDuration = CMTimeGetSeconds(inputVideoTrack.timeRange.duration);
    float inputFPS = inputVideoTrack.nominalFrameRate;
    NSUInteger inputFrameCount = round(inputFPS * inputDuration);

    // Calculate expected output metadata
    NSUInteger outputFrameCount = (inputFrameCount * 2) - 1;
//    float outputFPS = outputFrameCount / inputDuration;
    float outputFPS = inputFPS * 2.0;
    CMTime outputFrameDuration = CMTimeMakeWithSeconds(1.0 / outputFPS, kRSDurationResolution);


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
    AVMutableCompositionTrack *compositionVideoTrackPrior, *compositionVideoTrackNext;

    compositionVideoTrackPrior = [composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                          preferredTrackID:kCMPersistentTrackID_Invalid];
    compositionVideoTrackNext = [composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                         preferredTrackID:kCMPersistentTrackID_Invalid];

    CMPersistentTrackID priorID = compositionVideoTrackPrior.trackID;
    CMPersistentTrackID nextID = compositionVideoTrackNext.trackID;


    CMTimeRange priorTimeRange = inputVideoTrack.timeRange;
    priorTimeRange.start = CMTimeConvertScale(priorTimeRange.start, kRSDurationResolution, kCMTimeRoundingMethod_Default);
    priorTimeRange.duration = CMTimeConvertScale(priorTimeRange.duration, kRSDurationResolution, kCMTimeRoundingMethod_Default);

    CMTime priorEndTime = CMTimeAdd(priorTimeRange.start, priorTimeRange.duration);
    CMTimeRange nextTimeRange = CMTimeRangeMake(CMTimeAdd(priorTimeRange.start, outputFrameDuration), priorTimeRange.duration);

    NSLog(@"DEBUG:");
    CMTimeShow(outputFrameDuration);
    CMTimeRangeShow(priorTimeRange);
    CMTimeShow(priorEndTime);
    CMTimeRangeShow(nextTimeRange);


    [compositionVideoTrackPrior insertTimeRange:inputVideoTrack.timeRange
                                        ofTrack:inputVideoTrack
                                         atTime:priorTimeRange.start
                                          error:&err];
    [compositionVideoTrackPrior insertEmptyTimeRange:CMTimeRangeMake(priorEndTime, outputFrameDuration)];
    if (err)
    {
        NSLog(@"** Failed to insert prior video track into output composition: %@", err);
        return nil;
    }

    [compositionVideoTrackNext insertEmptyTimeRange:CMTimeRangeMake(priorTimeRange.start, outputFrameDuration)];
    [compositionVideoTrackNext insertTimeRange:inputVideoTrack.timeRange
                                       ofTrack:inputVideoTrack
                                        atTime:nextTimeRange.start
                                         error:&err];
    if (err)
    {
        NSLog(@"** Failed to insert next video track into output composition: %@", err);
        return nil;
    }


    NSLog(@"INS TEST:");
    CMTime peM2 = CMTimeSubtract(CMTimeSubtract(priorEndTime, outputFrameDuration), outputFrameDuration);
    CMTimeRange insAtr = CMTimeRangeMake(priorTimeRange.start, peM2);
    CMTimeRange insBtr = CMTimeRangeMake(peM2, CMTimeAdd(outputFrameDuration, outputFrameDuration));
    CMTimeRange insCtr = CMTimeRangeMake(CMTimeAdd(peM2, CMTimeAdd(outputFrameDuration, outputFrameDuration)), outputFrameDuration);
    CMTimeRangeShow(insAtr);
    CMTimeRangeShow(insBtr);
    CMTimeRangeShow(insCtr);

    RSFrameInterpolatorPassthroughInstruction *insA = [[RSFrameInterpolatorPassthroughInstruction alloc] initWithPassthroughTrackID:priorID
                                                                                                                       forTimeRange:insAtr];
    RSFrameInterpolatorInterpolationInstruction *insB = [[RSFrameInterpolatorInterpolationInstruction alloc] initWithPriorFrameTrackID:priorID
                                                                                                                   andNextFrameTrackID:nextID
                                                                                                                          forTimeRange:insBtr];
    RSFrameInterpolatorPassthroughInstruction *insC = [[RSFrameInterpolatorPassthroughInstruction alloc] initWithPassthroughTrackID:nextID
                                                                                                                       forTimeRange:insCtr];
    outputVideoComposition.instructions = @[insA, insB, insC];
    return outputVideoComposition;

    /*
     * Handle creating timeranges and instructions for output
     */


    NSMutableArray *instructions = [NSMutableArray arrayWithCapacity:outputFrameCount];

    NSUInteger framePrior, frameInbetween, frameNext;
    CMTime timePrior, timeInbetween, timeNext;
    CMTimeRange timeRangePrior, timeRangeInbetween, timeRangeNext;

    // Then handle all inbetween+next:
    for (NSUInteger frame = 2; frame < outputFrameCount; frame += 2)
    {
        @autoreleasepool {
            framePrior = frame - 2;
            frameInbetween = frame - 1;
            frameNext = frame;

            timePrior = CMTimeAdd(priorTimeRange.start, CMTimeMakeWithSeconds(framePrior / outputFPS, kRSDurationResolution));
            timeInbetween = CMTimeAdd(priorTimeRange.start, CMTimeMakeWithSeconds(frameInbetween / outputFPS, kRSDurationResolution));
            timeNext = CMTimeAdd(priorTimeRange.start, CMTimeMakeWithSeconds(frameNext / outputFPS, kRSDurationResolution));

            timeRangePrior = CMTimeRangeMake(timePrior, outputFrameDuration);
            timeRangeInbetween = CMTimeRangeMake(timeInbetween, outputFrameDuration);
            timeRangeNext = CMTimeRangeMake(timeNext, outputFrameDuration);

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
