//
//  RSExampleInterpolator.m
//  interframe
//
//  Created by Ryan Sullivan on 4/8/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSExampleInterpolator.h"

@interface RSExampleInterpolator ()

@property RSFrameInterpolator *interpolator;

@end

@implementation RSExampleInterpolator

-(id)initWithAsset:(AVAsset *)asset output:(NSURL *)output {
    if ((self = [super init]))
    {
        self.repPrior = [[ANImageBitmapRep alloc] init];
        self.repNext = [[ANImageBitmapRep alloc] init];

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
    [self.repPrior setContext:[CGContextCreator newARGBBitmapContextWithImage:state.priorImage]];
    [self.repNext setContext:[CGContextCreator newARGBBitmapContextWithImage:state.nextImage]];

    for (long x = 0; x < self.repPrior.bitmapSize.x; x++)
    {
        for (long y = 0; y < self.repPrior.bitmapSize.y; y++)
        {
            BMPoint point = BMPointMake(x, y);

            BMPixel pixelPrior = [self.repPrior getPixelAtPoint:point];
            BMPixel pixelNext = [self.repNext getPixelAtPoint:point];

            pixelPrior.red = (pixelPrior.red + pixelNext.red) / 2.0;
            pixelPrior.green = (pixelPrior.green + pixelNext.green) / 2.0;
            pixelPrior.blue = (pixelPrior.blue + pixelNext.blue) / 2.0;
            pixelPrior.alpha = (pixelPrior.alpha + pixelNext.alpha) / 2.0;

            [self.repPrior setPixel:pixelPrior atPoint:point];
        }
    }

    return CGImageRetain(self.repPrior.CGImage);
}
-(void)interpolatorFinished:(RSFrameInterpolator *)interpolator {
    NSLog(@"Finished!");
}

@end
