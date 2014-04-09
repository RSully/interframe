//
//  RSAverageSource.m
//  interframe
//
//  Created by Alex Nichol on 4/8/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSAverageSource.h"

@implementation RSAverageSource

- (id)initWithThreads:(NSUInteger)count {
    if ((self = [super init])) {
        threads = count;
        queue = [[NSOperationQueue alloc] init];
    }
    return self;
}

-(CGImageRef)newInterpolatedImageForInterpolator:(RSFrameInterpolator *)interpolator
                                       withState:(RSFrameInterpolationState *)state {
    ANImageBitmapRep * prior = [[ANImageBitmapRep alloc] initWithCGImage:state.priorImage];
    ANImageBitmapRep * next = [[ANImageBitmapRep alloc] initWithCGImage:state.nextImage];
    
    if (!dest) {
        BMPoint dims = prior.bitmapSize;
        dest = [[ANImageBitmapRep alloc] initWithSize:dims];
        
        input = malloc(sizeof(float) * (8 * dims.x * dims.y));
        output = malloc(sizeof(float) * (4 * dims.x * dims.y));
    }
    
    NSUInteger sampleCount = 4 * dest.bitmapSize.x * dest.bitmapSize.y;
    NSUInteger eachCount = sampleCount / threads;
    
    for (NSUInteger i = 0; i < threads; i++) {
        NSUInteger start = eachCount * i;
        NSUInteger vecSize = eachCount;
        if (i + 1 == threads) {
            vecSize = sampleCount - (eachCount * i);
        }
        NSBlockOperation * op = [NSBlockOperation blockOperationWithBlock:^{
            // cast data
            vDSP_vfltu8(prior.bitmapData + start, 1, &input[start * 2], 1, vecSize);
            vDSP_vfltu8(next.bitmapData + start, 1, &input[(start * 2) + vecSize], 1, vecSize);
            
            float leftMatrix[] = {0.5f, 0.5f};
            vDSP_mmul(leftMatrix, 1, &input[start * 2], 1, &output[start], 1, 1, vecSize, 2);
            vDSP_vfixu8(&output[start], 1, dest.bitmapData + start, 1, vecSize);
        }];
        [queue addOperation:op];
    }
    
    [queue waitUntilAllOperationsAreFinished];
    [dest setNeedsUpdate:YES];
    return CGImageRetain(dest.CGImage);
}

- (void)dealloc {
    if (input) free(input);
    if (output) free(output);
}

@end
