//
//  main.m
//  HFR
//
//  Created by Ryan Sullivan on 4/4/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        NSError *err = nil;

        NSURL *input = [NSURL URLWithString:@""];
//        NSURL *output = [NSURL URLWithString:@""];

        AVURLAsset *inputAsset = [AVURLAsset URLAssetWithURL:input options:@{}];

        AVAssetReader *inputReader = [[AVAssetReader alloc] initWithAsset:inputAsset error:&err];
        NSDictionary *videoSettings = @{
            (NSString*)kCVPixelBufferPixelFormatTypeKey: [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32RGBA]
        };
        AVAssetTrack *inputTrack = [[inputAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        AVAssetReaderOutput *inputOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:inputTrack
                                                                                outputSettings:videoSettings];
        [inputReader addOutput:inputOutput];
        [inputReader startReading];

        int i = 0;

        while (inputReader.status == AVAssetReaderStatusReading)
        {
            CMSampleBufferRef sampleBuffer = [inputOutput copyNextSampleBuffer];
            if (sampleBuffer)
            {
                CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
                CVPixelBufferLockBaseAddress(imageBuffer, 0);

                i++;
                NSLog(@"Got frame %d", i);

                CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
                CFRelease(sampleBuffer);
            }
        }
        
    }
    return 0;
}

