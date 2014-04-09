//
//  RSUpconverter.m
//  interframe
//
//  Created by Ryan Sullivan on 4/7/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSFrameInterpolator.h"

#define kRSFIBitmapInfo (kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst)
#define kRSFIPixelFormatType kCVPixelFormatType_32BGRA

@interface RSFrameInterpolator ()

@property (strong) NSMutableDictionary *defaultPixelSettings;

// Input assets
@property (strong) AVAsset *inputAsset;
@property (strong) AVAssetTrack *inputAssetVideoTrack;
// Input metadata
@property float inputFPS;
@property NSUInteger inputFrameCount;

// Output metadata
@property float outputFPS;
@property NSUInteger outputFrameCount;

@end


@implementation RSFrameInterpolator

-(id)initWithAsset:(AVAsset *)asset output:(NSURL *)output {
    if ((self = [self init]))
    {
        NSError *error = nil;

        self.inputAsset = asset;

        // Setup input metadata
        self.inputAssetVideoTrack = [self.inputAsset tracksWithMediaType:AVMediaTypeVideo][0];
        self.inputFPS = self.inputAssetVideoTrack.nominalFrameRate;
        self.inputFrameCount = round(self.inputFPS * CMTimeGetSeconds(self.inputAsset.duration));

        // Calculate expected output metadata
        self.outputFPS = (self.inputFPS * 2.0); // TODO: this isn't right exactly
        self.outputFrameCount = (self.inputFrameCount * 2.0) - 1;



//        // Setup output writer
//        NSString *fileType = CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)([output pathExtension]), NULL));
//        NSDictionary *outputSettings = @{
//                                         AVVideoCodecKey: AVVideoCodecH264,
//                                         AVVideoHeightKey: @(self.inputAssetVideoTrack.naturalSize.height),
//                                         AVVideoWidthKey: @(self.inputAssetVideoTrack.naturalSize.width),
////                                         AVVideoCompressionPropertiesKey: @{
////                                                 AVVideoProfileLevelKey: AVVideoProfileLevelH264High41,
////                                                 AVVideoAverageBitRateKey: @(5000)
////                                                 }
//                                         };
    }
    return self;
}

-(void)setCompositor:(id<RSFrameInterpolatorCompositor>)compositor {
    _compositor = compositor;
    // TODO: set composition's compositor
}


-(void)interpolate {

}

@end
