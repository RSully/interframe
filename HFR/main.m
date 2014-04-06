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
//        NSURL *output = [NSURL URLWithString:@""];

        AVURLAsset *inputAsset = [AVURLAsset URLAssetWithURL:input options:@{}];

        AVAssetReader *inputReader = [[AVAssetReader alloc] initWithAsset:inputAsset error:&err];
        NSDictionary *videoSettings = @{
            (NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        };
        //kCVPixelFormatType_32RGBA
        //kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        AVAssetTrack *inputTrack = [inputAsset tracksWithMediaType:AVMediaTypeVideo][0];
        AVAssetReaderOutput *inputOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:inputTrack
                                                                                outputSettings:videoSettings];
        [inputReader addOutput:inputOutput];
        [inputReader startReading];


        while (inputReader.status == AVAssetReaderStatusReading)
        {
            CMSampleBufferRef sampleBuffer = [inputOutput copyNextSampleBuffer];
            if (sampleBuffer)
            {
                CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
                CVPixelBufferLockBaseAddress(imageBuffer, 0);

                uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
                size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
                size_t width = CVPixelBufferGetWidth(imageBuffer);
                size_t height = CVPixelBufferGetHeight(imageBuffer);
                CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

                CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
                CGImageRef newImage = CGBitmapContextCreateImage(newContext);
                CGContextRelease(newContext); 
                
                CGColorSpaceRelease(colorSpace);

                CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
                CFRelease(sampleBuffer);

                NSLog(@"%@", [[NSImage alloc] initWithCGImage:newImage size:NSMakeSize(width, height)]);
            }
        }
        NSLog(@"%@", inputReader.error);
        
    }
    return 0;
}

