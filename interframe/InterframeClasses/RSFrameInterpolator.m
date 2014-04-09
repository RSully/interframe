//
//  RSUpconverter.m
//  interframe
//
//  Created by Ryan Sullivan on 4/7/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSFrameInterpolator.h"


@interface RSFrameInterpolator ()

@property (strong) NSMutableDictionary *defaultPixelSettings;

// Input assets
@property (strong) AVAsset *inputAsset;
@property (strong) AVAssetTrack *inputAssetVideoTrack;
// Input metadata
@property float inputFPS;
@property NSUInteger inputFrameCount;

// Output composition
@property (strong) AVMutableComposition *outputComposition;
@property (strong) AVMutableVideoComposition *outputVideoComposition;
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


        self.outputComposition = [AVMutableComposition composition];
        self.outputVideoComposition = [AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:self.inputAsset];
        self.outputVideoComposition.frameDuration = CMTimeMakeWithSeconds(1 / self.outputFPS, NSEC_PER_SEC);

    }
    return self;
}

-(void)setCompositor:(Class<RSFrameInterpolatorCompositor>)compositor {
    self.outputVideoComposition.customVideoCompositorClass = compositor;
}


-(void)interpolate {

}

@end
