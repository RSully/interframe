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

CGImageRef CreateInbetweenFrame(CGImageRef frame1, CGImageRef frame2)
{
    // TODO: implement this better ;)
    return CGImageCreateCopy(frame2);
}
CGImageRef CreateImageFromSampleBuffer(CMSampleBufferRef sampleBuffer)
{
    // 32BGRA only?
    // http://stackoverflow.com/questions/3305862/uiimage-created-from-cmsamplebufferref-not-displayed-in-uiimageview

    // Access internal imagebuffer from samplebuffer
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    // Get information of the image
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);

    // Using device RGB - is this best?
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    // Create a context from samplebuffer to get CGImage
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef image = CGBitmapContextCreateImage(context);

    // Cleanup
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);

    return image;
}
CVPixelBufferRef ImageBufferForImage(CGImageRef image)
{
    // https://github.com/unixpickle/VideoExporter/blob/master/AVExportTest/VideoExporter.m
    // http://stackoverflow.com/questions/3741323/how-do-i-export-uiimage-array-as-a-movie/3742212#3742212

    // Later on we should use a pool thing for efficiency
//    NSDictionary *pixelAttributes = @{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
//    AVAssetWriterInputPixelBufferAdaptor *adaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:nil
//                                                                                               sourcePixelBufferAttributes:pixelAttributes];
//
//    CVImageBufferRef imageBuffer = NULL;
//    CVReturn status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, adaptor.pixelBufferPool, &imageBuffer);

    size_t imageWidth = CGImageGetWidth(image);
    size_t imageHeight = CGImageGetHeight(image);
    NSDictionary *options = @{(NSString *)kCVPixelBufferCGImageCompatibilityKey: @(YES), (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @(YES)};

    CVPixelBufferRef imageBuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, imageWidth, imageHeight, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)(options), &imageBuffer);
    if (status != 0) return NULL;

    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    // Get information of the image
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);

    // Using device RGB - is this best?
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    // Create a context where the pixelbuffer is
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);

    // Draw the image on the pixel data
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);

    // Cleanup
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);

    return imageBuffer;
}


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


        // Reader
        AVAssetReader *inputAssetVideoReader = [[AVAssetReader alloc] initWithAsset:inputAsset error:&err];
        NSDictionary *inputAssetVideoReaderSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
        AVAssetReaderTrackOutput *inputAssetVideoReaderOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:inputAssetVideo
                                                                                                           outputSettings:inputAssetVideoReaderSettings];
        [inputAssetVideoReader addOutput:inputAssetVideoReaderOutput];
        [inputAssetVideoReader startReading];


        // Think this is right for "duration" of 1 frame
        CMTime timeRangeFrame = CMTimeMake(1, outputFramePerSecond);
        CMTime timeRangeFrameSource = CMTimeMake(1, inputFramePerSecond);

        CGImageRef firstImg = NULL, inbetweenImg = NULL, lastImg = NULL;
        CMSampleBufferRef firstSample = NULL, inbetweenSample = NULL, lastSample = NULL;

        for (NSUInteger frame = 2; frame < outputFrameCount; frame += 2)
        {
            if (frame > 400) break;

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

            CMTimeRange inbetweenFrameTimeRange = CMTimeRangeMake(inbetweenFrameTime, timeRangeFrame);
            CMTimeRange firstFrameTimeRangeSource = CMTimeRangeMake(firstFrameTimeSource, timeRangeFrameSource);
            CMTimeRange lastFrameTimeRangeSource = CMTimeRangeMake(lastFrameTimeSource, timeRangeFrameSource);

            if (firstFrame < 1)
            {
                // Only insert the first frame for the actual first frame
                // Otherwise we'd be duplicating this effort

                firstSample = [inputAssetVideoReaderOutput copyNextSampleBuffer];
                firstImg = CreateImageFromSampleBuffer(firstSample);
                CFRelease(firstSample), firstSample = NULL;


                // TODO: WRITE FIRSTFRAME TO OUTPUT
            }

            lastSample = [inputAssetVideoReaderOutput copyNextSampleBuffer];
            lastImg = CreateImageFromSampleBuffer(lastSample);
            CFRelease(lastSample), lastSample = NULL;

            inbetweenImg = CreateInbetweenFrame(firstImg, lastImg);
            CVImageBufferRef inbetweenBuffer = ImageBufferForImage(inbetweenImg);

            // TODO: WRITE INBETWEEN TO OUTPUT
            CFRelease(inbetweenBuffer), inbetweenBuffer = NULL;
            // TODO: WRITE LASTFRAME TO OUTPUT
            // Not releasing lastImg because we reuse it


            // Release objects
            CGImageRelease(firstImg), firstImg = NULL;
            CGImageRelease(inbetweenImg), inbetweenImg = NULL;
            // Set first to last for next iteration
            firstImg = lastImg, lastImg = NULL;
        }

        if (firstImg)
        {
            CGImageRelease(firstImg);
        }

        NSLog(@"Finished main conversion");

        // Might need this for adding audio?
        // http://stackoverflow.com/questions/5640657/avfoundation-assetwriter-generate-movie-with-images-and-audio
        // http://stackoverflow.com/questions/6061092/make-movie-file-with-picture-array-and-song-file-using-avasset
//        NSLog(@"Presets: %@", [AVAssetExportSession exportPresetsCompatibleWithAsset:outputComp]);
//        AVAssetExportSession *export = [AVAssetExportSession exportSessionWithAsset:outputComp presetName:AVAssetExportPresetPassthrough];
//        export.outputFileType = AVFileTypeMPEG4;
//        export.outputURL = output;
//        [export exportAsynchronouslyWithCompletionHandler:^{
//            NSLog(@".. done?");
//        }];
//
//        NSLog(@"Running runloop");
//        [[NSRunLoop currentRunLoop] run];

        NSLog(@"Exiting...");

    }
    return 0;
}

