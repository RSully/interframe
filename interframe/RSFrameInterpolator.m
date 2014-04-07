//
//  RSUpconverter.m
//  interframe
//
//  Created by Ryan Sullivan on 4/7/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSFrameInterpolator.h"
#import <AVFoundation/AVFoundation.h>
#import <AppKit/AppKit.h>

#define kRSUBitmapInfo (kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst)


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
@property (strong) AVAssetWriterInputPixelBufferAdaptor *outputWriterInputAdapter;
// Output metadata
@property float outputFPS;
@property NSUInteger outputFrameCount;

@end


@implementation RSFrameInterpolator

-(id)initWithAsset:(AVAsset *)asset {
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
            @throw [NSException exceptionWithName:@"RSFIException" reason:@"Failed to instantiate inputAssetVideoReader" userInfo:@{@"error": error}];
        }
        self.inputAssetVideoReaderOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:self.inputAssetVideoTrack
                                                                                      outputSettings:self.defaultPixelSettings];
        [self.inputAssetVideoReader addOutput:self.inputAssetVideoReaderOutput];
    }
    return self;
}

-(void)interpolate {
    // LOGICCCC
}

/**
 * Create a CGImage from a CVPixelBuffer
 * This may only work on 32BGRA sources
 *
 * Some logic from: http://stackoverflow.com/questions/3305862/uiimage-created-from-cmsamplebufferref-not-displayed-in-uiimageview
 */
-(CGImageRef)createCGImageFromPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    // Get info about image
    void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);

    // Using device RGB - is this best?
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    // Create a context from pixelBuffer to get a CGImage
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kRSUBitmapInfo);
    // Fetch the image
    CGImageRef image = CGBitmapContextCreateImage(context);

    // Cleanup
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    return image;
}
/**
 * Create a CVPixelBuffer from a CGImage
 */
-(CVPixelBufferRef)createPixelBufferFromCGImage:(CGImageRef)image {
    return NULL;
}

@end
