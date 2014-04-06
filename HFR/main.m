//
//  main.m
//  HFR
//
//  Created by Ryan Sullivan on 4/4/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AppKit/AppKit.h>

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        NSError *err = nil;

        NSURL *input = [NSURL fileURLWithPath:@""];
        NSURL *output = [NSURL fileURLWithPath:@""];

        AVURLAsset *inputAsset = [AVURLAsset URLAssetWithURL:input options:@{}];
        AVAssetTrack *inputAssetVideo = [inputAsset tracksWithMediaType:AVMediaTypeVideo][0];

        // Using ceil because you can't have fraction of a frame
        // There *must* be a better way to get the amount of frames, I mean c'mon!
        NSUInteger inputFrameCount = ceil(inputAssetVideo.nominalFrameRate * CMTimeGetSeconds(inputAsset.duration));
        NSLog(@"Frame count: %lu (%f fps)", inputFrameCount, inputAssetVideo.nominalFrameRate);
        float inputFramePerSecond = inputAssetVideo.nominalFrameRate;
        // Frame amount is 2x-1 because we can only generate inbetween, not perfect double
        NSUInteger outputFrameCount = (inputFrameCount * 2.0) - 1;
        float outputFramePerSecond = inputFramePerSecond * 2.0;

        // Create an output composition, I guess?
        AVMutableComposition *outputComp = [AVMutableComposition composition];
        AVMutableCompositionTrack *outputTrack = [outputComp addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];

        // Create an image generator
        AVAssetImageGenerator *outputGenerator = [[AVAssetImageGenerator alloc] initWithAsset:outputComp];


        for (NSUInteger frame = 2; frame < outputFrameCount; frame += 2)
        {
            if (frame > 500) break;

            // math         explain                 output      input
            // -----------------------------------------------------------
            // frame - 2 = first source frame   // 0 2 4    // 0 1 2
            // frame - 1 = inbetween frame      // 1 3 5    //
            // frame - 0 = last source frame    // 2 4 6    // 1 2 3
            // -----------------------------------------------------------

            // Frame numbers
            NSUInteger firstFrame = frame - 2;
            NSUInteger inbetweenFrame = frame - 1;
            NSUInteger lastFrame = frame;
            NSUInteger firstFrameSource = firstFrame / 2;
            NSUInteger lastFrameSource = lastFrame / 2;

            // Frame times
            CMTime firstFrameTime = CMTimeMake(firstFrame, outputFramePerSecond);
            CMTime inbetweenFrameTime = CMTimeMake(inbetweenFrame, outputFramePerSecond);
            CMTime lastFrameTime = CMTimeMake(lastFrame, outputFramePerSecond);
            CMTime firstFrameTimeSource = CMTimeMake(firstFrameSource, inputFramePerSecond);
            CMTime lastFrameTimeSource = CMTimeMake(lastFrameSource, inputFramePerSecond);

            // Think this is right for "duration" of 1 frame
            CMTime timeRangeFrame = CMTimeMake(1, outputFramePerSecond);
            CMTime timeRangeFrameSource = CMTimeMake(1, inputFramePerSecond);

            CMTimeRange inbetweenFrameTimeRange = CMTimeRangeMake(inbetweenFrameTime, timeRangeFrame);
            CMTimeRange firstFrameTimeRangeSource = CMTimeRangeMake(firstFrameTimeSource, timeRangeFrameSource);
            CMTimeRange lastFrameTimeRangeSource = CMTimeRangeMake(lastFrameTimeSource, timeRangeFrameSource);

            BOOL okFirst = [outputTrack insertTimeRange:firstFrameTimeRangeSource ofTrack:inputAssetVideo atTime:firstFrameTime error:&err];
            BOOL okLast = [outputTrack insertTimeRange:lastFrameTimeRangeSource ofTrack:inputAssetVideo atTime:lastFrameTime error:&err];

            CGImageRef firstImg = [outputGenerator copyCGImageAtTime:firstFrameTime actualTime:nil error:&err];
            CGImageRef lastImg = [outputGenerator copyCGImageAtTime:lastFrameTime actualTime:nil error:&err];
            // This is where we would call our generator:
            CGImageRef inbetweenImg = CGImageCreateCopy(lastImg);

        }


//        NSLog(@"Presets: %@", [AVAssetExportSession exportPresetsCompatibleWithAsset:outputComp]);
//        AVAssetExportSession *export = [AVAssetExportSession exportSessionWithAsset:outputComp presetName:AVAssetExportPresetPassthrough];
//        export.outputFileType = AVFileTypeMPEG4;
//        export.outputURL = output;
//        [export exportAsynchronouslyWithCompletionHandler:^{
//            NSLog(@".. done?");
//        }];

        [[NSRunLoop currentRunLoop] run];

    }
    return 0;
}

