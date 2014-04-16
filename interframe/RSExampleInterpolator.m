//
//  RSExampleInterpolator.m
//  interframe
//
//  Created by Ryan Sullivan on 4/8/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSExampleInterpolator.h"
#import <Accelerate/Accelerate.h>
#import "RSFrameInterpolatorDefaultCompositor.h"

@interface RSExampleInterpolator ()

@property (nonatomic, strong) RSFrameInterpolator *interpolator;
@property (nonatomic, strong) NSURL *outputUrl;

@end


@implementation RSExampleInterpolator

-(id)initWithAsset:(AVAsset *)asset output:(NSURL *)output {
    if ((self = [super init]))
    {
        self.outputUrl = output;

        self.interpolator = [[RSFrameInterpolator alloc] initWithAsset:asset];
        self.interpolator.delegate = self;
    }
    return self;
}

-(void)interpolate {
    [self.interpolator interpolateToOutput:self.outputUrl];
}

-(void)interpolatorFinished:(RSFrameInterpolator *)interpolator {
    NSLog(@"Finished!");
    exit(0);
}

@end
