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

@property RSFrameInterpolator *interpolator;

@end

@implementation RSExampleInterpolator

-(id)initWithAsset:(AVAsset *)asset output:(NSURL *)output {
    if ((self = [super init]))
    {
        self.interpolator = [[RSFrameInterpolator alloc] initWithAsset:asset output:output];
        self.interpolator.delegate = self;
    }
    return self;
}

-(void)interpolate {
    [self.interpolator interpolate];
}

-(CGImageRef)newInterpolatedImageForInterpolator:(RSFrameInterpolator *)interpolator
                                       withState:(RSFrameInterpolationState *)state {
    NSLog(@"-createInterpolated %@ %@ %lu", state.priorImage, state.nextImage, (unsigned long)state.frame);
//    if (!state.priorImage || !state.nextImage) return NULL;

    ANImageBitmapRep *repPrior = [[ANImageBitmapRep alloc] initWithCGImage:state.priorImage];
    ANImageBitmapRep *repNext = [[ANImageBitmapRep alloc] initWithCGImage:state.nextImage];

    ANImageBitmapRep *repDest = [[ANImageBitmapRep alloc] initWithSize:repPrior.bitmapSize];

    size_t dataLength = repPrior.bitmapSize.x * repPrior.bitmapSize.y;

    unsigned char *dataPrior = repPrior.bitmapData;
    unsigned char *dataNext = repNext.bitmapData;
    float *buffer = malloc(sizeof(float) * (dataLength * 4 * 2));
    float *result = malloc(sizeof(float) * (dataLength * 4));

    vDSP_vfltu8(dataPrior, 1, buffer, 1, dataLength * 4);
    vDSP_vfltu8(dataNext, 1, &buffer[dataLength * 4], 1, dataLength * 4);

    float leftMatrix[] = {0.5f, 0.5f};
    vDSP_mmul(leftMatrix, 1, buffer, 1, result, 1, 1, dataLength * 4, 2);
    free(buffer);

    vDSP_vfixu8(result, 1, repDest.bitmapData, 1, dataLength * 4);
    free(result);

    [repDest setNeedsUpdate:YES];

    return CGImageRetain(repDest.CGImage);
}
-(void)interpolatorFinished:(RSFrameInterpolator *)interpolator {
    NSLog(@"Finished!");
}

@end
