//
//  RSUpconverter.m
//  interframe
//
//  Created by Ryan Sullivan on 4/7/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSFrameInterpolator.h"
#import <AppKit/AppKit.h>

#define kRSFIBitmapInfo (kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst)


@interface RSFrameInterpolator ()

@property (strong) NSDictionary *defaultPixelSettings;

// Input assets
@property (strong) AVAsset *inputAsset;
@property (strong) AVAssetTrack *inputAssetVideoTrack;
// Input readers
@property (strong) AVAssetReader *inputAssetVideoReader;
@property (strong) AVAssetReaderTrackOutput *inputAssetVideoReaderOutput;
// Input metadata
@property float inputFPS;
@property NSUInteger inputFrameCount;

// Output writer
@property (strong) AVAssetWriter *outputWriter;
@property (strong) AVAssetWriterInput *outputWriterInput;
@property (strong) AVAssetWriterInputPixelBufferAdaptor *outputWriterInputAdapter;
// Output metadata
@property float outputFPS;
@property NSUInteger outputFrameCount;

@end


@implementation RSFrameInterpolator

-(id)initWithAsset:(AVAsset *)asset output:(NSURL *)output {
    if ((self = [self init]))
    {
        NSError *error = nil;
        self.defaultPixelSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};

        self.inputAsset = asset;

        // Setup input metadata
        self.inputAssetVideoTrack = [self.inputAsset tracksWithMediaType:AVMediaTypeVideo][0];
        self.inputFPS = self.inputAssetVideoTrack.nominalFrameRate;
        self.inputFrameCount = round(self.inputFPS * CMTimeGetSeconds(self.inputAsset.duration));

        // Calculate expected output metadata
        self.outputFPS = self.inputFPS * 2.0;
        self.outputFrameCount = (self.inputFrameCount * 2.0) - 1;

        // Setup input reader
        self.inputAssetVideoReader = [[AVAssetReader alloc] initWithAsset:self.inputAsset error:&error];
        if (error)
        {
            // TODO: better error system
            @throw [NSException exceptionWithName:@"RSFIException" reason:@"Failed to instantiate inputAssetVideoReader" userInfo:@{@"error": error}];
        }
        self.inputAssetVideoReaderOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:self.inputAssetVideoTrack
                                                                                      outputSettings:self.defaultPixelSettings];
        [self.inputAssetVideoReader addOutput:self.inputAssetVideoReaderOutput];

        // Setup output writer
        NSString *fileType = CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)([output pathExtension]), NULL));
        self.outputWriter = [[AVAssetWriter alloc] initWithURL:output fileType:fileType error:&error];
        NSDictionary *outputSettings = @{AVVideoCodecKey: AVVideoCodecH264, AVVideoHeightKey: @(self.inputAssetVideoTrack.naturalSize.height), AVVideoWidthKey: @(self.inputAssetVideoTrack.naturalSize.width)};
        self.outputWriterInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:outputSettings];
        self.outputWriterInputAdapter = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:self.outputWriterInput
                                                                                   sourcePixelBufferAttributes:self.defaultPixelSettings];
        [self.outputWriter addInput:self.outputWriterInput];
    }
    return self;
}

-(void)interpolate {

    BOOL readingOK = [self.inputAssetVideoReader startReading];
    if (!readingOK)
    {
        @throw [NSException exceptionWithName:@"RSFIException" reason:@"Failed to read inputAssetVideoReader" userInfo:nil];
    }
    BOOL writingOK = [self.outputWriter startWriting];
    if (!writingOK)
    {
        @throw [NSException exceptionWithName:@"RSFIException" reason:@"Failed to write outputWriter" userInfo:nil];
    }
    [self.outputWriter startSessionAtSourceTime:kCMTimeZero];

    NSUInteger framePrior, frameInbetween, frameNext;
    NSUInteger framePriorInput, frameNextInput;
    CMSampleBufferRef sampleBufferPrior = NULL, sampleBufferNext = NULL;
    CVPixelBufferRef pixelBufferPrior = NULL, pixelBufferInbetween = NULL, pixelBufferNext = NULL;
    CGImageRef imagePrior = NULL, imageInbetween = NULL, imageNext = NULL;
    CMTime timePrior, timeInbetween, timeNext;

    // expr         explain                 output      input
    // -----------------------------------------------------------
    // frame - 2 = first source frame   // 0 2 4    // 0 1 2
    // frame - 1 = inbetween frame      // 1 3 5    //
    // frame - 0 = last source frame    // 2 4 6    // 1 2 3
    // -----------------------------------------------------------
    for (NSUInteger frame = 2; frame < self.outputFrameCount; frame += 2)
    {
        // TODO: remove, debug only
        if (frame > 400) break;

        // Frame numbers for output
        framePrior = frame - 2;
        frameInbetween = frame - 1;
        frameNext = frame;

        // Frame numbers for input
        framePriorInput = framePrior / 2;
        frameNextInput = frameNext / 2;

        // Frame times
        timePrior = CMTimeMake(framePrior, self.outputFPS);
        timeInbetween = CMTimeMake(frameInbetween, self.outputFPS);
        timeNext = CMTimeMake(frameNext, self.outputFPS);


        // Handle first frame special
        if (framePrior == 0)
        {
            sampleBufferPrior = [self.inputAssetVideoReaderOutput copyNextSampleBuffer];
            pixelBufferPrior = CMSampleBufferGetImageBuffer(sampleBufferPrior);

            imagePrior = [self createCGImageFromPixelBuffer:pixelBufferPrior];

            // We don't want to duplicate writes, so do it here
            CMTimeShow(timePrior);
            [self lazilyAppendPixelBuffer:pixelBufferPrior withPresentationTime:timePrior];
        }

        sampleBufferNext = [self.inputAssetVideoReaderOutput copyNextSampleBuffer];
        pixelBufferNext = CMSampleBufferGetImageBuffer(sampleBufferNext);
        imageNext = [self createCGImageFromPixelBuffer:pixelBufferNext];


        // TODO: delegate this logic to interpolator
        imageInbetween = CGImageCreateCopy(imagePrior);
        pixelBufferInbetween = [self createPixelBufferFromCGImage:imageInbetween];


        CMTimeShow(timeInbetween);
//        [self lazilyAppendPixelBuffer:pixelBufferInbetween withPresentationTime:timeInbetween];
        CMTimeShow(timeNext);
        [self lazilyAppendPixelBuffer:pixelBufferNext withPresentationTime:timeNext];


        // We need to hang onto pixelBufferNext, imageNext
        // by extension we need to hang onto sampleBufferNext to release it
        // These all need to go to "prior" vars
        pixelBufferPrior = pixelBufferNext;
        CGImageRelease(imagePrior), imagePrior = imageNext;
        CFRelease(sampleBufferPrior), sampleBufferPrior = sampleBufferNext;

        // Cleanup inbetween
        CGImageRelease(imageInbetween), imageInbetween = NULL;
        CVPixelBufferRelease(pixelBufferInbetween), pixelBufferInbetween = NULL;

    }

    [self.outputWriter finishWritingWithCompletionHandler:^{
        NSLog(@"Finished writing");
        // TODO: ?
    }];

}

-(void)lazilyAppendPixelBuffer:(CVPixelBufferRef)pixelBuffer withPresentationTime:(CMTime)presentationTime {
    while (!self.outputWriterInput.readyForMoreMediaData) {
        [NSThread sleepForTimeInterval:0.01];
    }
    [self.outputWriterInputAdapter appendPixelBuffer:pixelBuffer withPresentationTime:presentationTime];
}

/**
 * Create a CGImage from a CVPixelBuffer
 * This may only work on 32BGRA sources
 *
 * Some logic from: http://stackoverflow.com/questions/3305862/uiimage-created-from-cmsamplebufferref-not-displayed-in-uiimageview
 */
-(CGImageRef)createCGImageFromPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    CGContextRef context = [self createContextFromPixelBuffer:pixelBuffer];

    // Fetch the image
    CGImageRef image = CGBitmapContextCreateImage(context);

    // Cleanup
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    return image;
}
/**
 * Create a CVPixelBuffer from a CGImage
 */
-(CVPixelBufferRef)createPixelBufferFromCGImage:(CGImageRef)image {
    CVPixelBufferRef pixelBuffer = NULL;
    NSLog(@"%d", self.outputWriterInput.readyForMoreMediaData);
    CVReturn status = CVPixelBufferPoolCreatePixelBuffer(NULL, self.outputWriterInputAdapter.pixelBufferPool, &pixelBuffer);
    if (status != 0) return NULL;

    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    CGContextRef context = [self createContextFromPixelBuffer:pixelBuffer];

    // Draw the image onto pixelBuffer
    CGContextDrawImage(context, CGRectMake(0, 0, CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetWidth(pixelBuffer)), image);

    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    return pixelBuffer;
}

-(CGContextRef)createContextFromPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    // Get info about image
    void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);

    // Using device RGB - is this best?
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kRSFIBitmapInfo);

    CGColorSpaceRelease(colorSpace);
    return context;
}

@end
