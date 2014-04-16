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
#import "RSFrameInterpolatorDefaultCompositor.h"

//#define kRSDurationResolution 300
#define kRSDurationResolution NSEC_PER_SEC
//#define kRSDurationResolution 240

@interface RSFrameInterpolator ()

/*
 * Given/init vars
 */

@property (strong) AVAsset *inputAsset;
@property (strong) NSURL *outputUrl;

@end


@implementation RSFrameInterpolator

-(id)initWithAsset:(AVAsset *)asset {
    if ((self = [self init]))
    {
        self.inputAsset = asset;
    }
    return self;
}



+(AVMutableVideoComposition *)buildVideoCompositionForComposition:(AVMutableComposition*)composition
                                                    andVideoTrack:(AVAssetTrack *)inputVideoTrack
                                             withCustomCompositor:(Class<AVVideoCompositing>)compositor {

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
    outputVideoComposition.customVideoCompositorClass = compositor;
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

    // Add the instructions
    outputVideoComposition.instructions = instructions;

    return outputVideoComposition;
}


-(void)interpolateToOutput:(NSURL *)output {

    /*
     * General variables
     */

    NSError *err = nil;

    AVAsset *inputAsset = self.inputAsset;
    id<AVVideoCompositing> compositor = [self newCompositor];
    // Pick first video track. Maybe not later?
    AVAssetTrack *inputTrack = [inputAsset tracksWithMediaType:AVMediaTypeVideo][0];

    /*
     * Setup input/reader
     */

    NSDictionary *compositorOutputSettings = [compositor sourcePixelBufferAttributes];

    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:inputAsset error:&err];
    AVAssetReaderTrackOutput *readerOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:inputTrack outputSettings:compositorOutputSettings];

    if (![reader canAddOutput:readerOutput])
    {
        [self.delegate interpolatorFailed:self withError:nil];
        return;
    }
    [reader addOutput:readerOutput];

    /*
     * Setup output/writer
     */

    /*
     * Setup compositor and render context
     *
     * When does this happen??
     */


    [self.delegate interpolatorFinished:self];

}

#pragma mark Methods used for -interpolateToOutput:

-(id<AVVideoCompositing>)newCompositor {
    Class compositorClass = self.customCompositor;
    if (!compositorClass)
    {
        compositorClass = [RSFrameInterpolatorDefaultCompositor class];
    }
    return [compositorClass new];
}

@end
