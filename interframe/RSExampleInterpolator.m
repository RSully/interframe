//
//  RSExampleInterpolator.m
//  interframe
//
//  Created by Ryan Sullivan on 4/8/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSExampleInterpolator.h"
#import <Accelerate/Accelerate.h>

@interface RSExampleInterpolator ()

@property (nonatomic, strong) RSFrameInterpolator *interpolator;

@end


@implementation RSExampleInterpolator

-(id)initWithAsset:(AVAsset *)asset output:(NSURL *)output {
    if ((self = [super init]))
    {
        self.interpolator = [[RSFrameInterpolator alloc] initWithAsset:asset output:output];
        self.interpolator.delegate = self;
        self.interpolator.compositor = [self class];
    }
    return self;
}

-(void)interpolate {
    [self.interpolator interpolate];
}

-(void)interpolatorFinished:(RSFrameInterpolator *)interpolator {
    NSLog(@"Finished!");
}

+(CGImageRef)newInterpolatedImageWithState:(RSFrameInterpolationState *)state {
    NSLog(@"-newInterpolatedImage");

    ANImageBitmapRep *prior = [[ANImageBitmapRep alloc] initWithCGImage:state.priorImage];
    ANImageBitmapRep *next = [[ANImageBitmapRep alloc] initWithCGImage:state.nextImage];

    BMPoint dims = prior.bitmapSize;
    ANImageBitmapRep *dest = [[ANImageBitmapRep alloc] initWithSize:dims];

    float *dspInput = malloc(sizeof(float) * (4 * 2 * dims.x * dims.y));
    float *dspOutput = malloc(sizeof(float) * (4 * dims.x * dims.y));

    NSUInteger sampleCount = 4 * dest.bitmapSize.x * dest.bitmapSize.y;

    // cast data
    vDSP_vfltu8(prior.bitmapData, 1, dspInput, 1, sampleCount);
    vDSP_vfltu8(next.bitmapData, 1, &dspInput[sampleCount], 1, sampleCount);

    // compute averages
    float leftMatrix[] = {0.5f, 0.5f};
    vDSP_mmul(leftMatrix, 1, dspInput, 1, dspOutput, 1, 1, sampleCount, 2);
    vDSP_vfixu8(dspOutput, 1, dest.bitmapData, 1, sampleCount);

    // return image
    [dest setNeedsUpdate:YES];
    return CGImageRetain(dest.CGImage);
}

@end
