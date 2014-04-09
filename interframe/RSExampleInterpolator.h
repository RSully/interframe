//
//  RSExampleInterpolator.h
//  interframe
//
//  Created by Ryan Sullivan on 4/8/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#import "RSFrameInterpolator.h"
#import "ANImageBitmapRep.h"
#import "RSAverageSource.h"

@interface RSExampleInterpolator : NSObject <RSFrameInterpolatorDelegate> {
    RSAverageSource * source;
}

-(id)initWithAsset:(AVAsset *)asset output:(NSURL *)output;

-(void)interpolate;

@end
