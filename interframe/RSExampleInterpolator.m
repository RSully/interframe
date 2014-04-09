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

@property (nonatomic, strong) ANImageBitmapRep *dest;
@property (nonatomic) float *dspInput;
@property (nonatomic) float *dspOutput;

@end


@implementation RSExampleInterpolator

-(id)initWithAsset:(AVAsset *)asset output:(NSURL *)output {
    if ((self = [super init]))
    {
        self.interpolator = [[RSFrameInterpolator alloc] initWithAsset:asset output:output];
        self.interpolator.delegate = self;
        self.interpolator.source = self;
    }
    return self;
}

-(void)dealloc {
    if (self.dspInput) free(self.dspInput);
    if (self.dspOutput) free(self.dspOutput);
}


-(void)interpolate {
    [self.interpolator interpolate];
}

-(void)interpolatorFinished:(RSFrameInterpolator *)interpolator {
    NSLog(@"Finished!");
}

-(CGImageRef)newInterpolatedImageForInterpolator:(RSFrameInterpolator *)interpolator
                                       withState:(RSFrameInterpolationState *)state {
    NSLog(@"-newInterpolatedImage");

    ANImageBitmapRep *prior = [[ANImageBitmapRep alloc] initWithCGImage:state.priorImage];
    ANImageBitmapRep *next = [[ANImageBitmapRep alloc] initWithCGImage:state.nextImage];

    if (!self.dest) {
        // Just alloc these once

        BMPoint dims = prior.bitmapSize;
        self.dest = [[ANImageBitmapRep alloc] initWithSize:dims];

        self.dspInput = malloc(sizeof(float) * (4 * 2 * dims.x * dims.y));
        self.dspOutput = malloc(sizeof(float) * (4 * dims.x * dims.y));
    }

    NSUInteger sampleCount = 4 * self.dest.bitmapSize.x * self.dest.bitmapSize.y;

    // cast data
    vDSP_vfltu8(prior.bitmapData, 1, self.dspInput, 1, sampleCount);
    vDSP_vfltu8(next.bitmapData, 1, &self.dspInput[sampleCount], 1, sampleCount);

    float leftMatrix[] = {0.5f, 0.5f};
    vDSP_mmul(leftMatrix, 1, self.dspInput, 1, self.dspOutput, 1, 1, sampleCount, 2);
    vDSP_vfixu8(self.dspOutput, 1, self.dest.bitmapData, 1, sampleCount);

    [self.dest setNeedsUpdate:YES];
    return CGImageRetain(self.dest.CGImage);
}

@end
