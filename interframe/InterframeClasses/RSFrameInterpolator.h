//
//  RSUpconverter.h
//  interframe
//
//  Created by Ryan Sullivan on 4/7/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AVFoundation/AVFoundation.h>
#import "RSIInterpolationCompositing.h"

@class RSFrameInterpolator;

@protocol RSFrameInterpolatorDelegate <NSObject>
-(void)interpolatorFinished:(RSFrameInterpolator *)interpolator;
-(void)interpolatorFailed:(RSFrameInterpolator *)interpolator withError:(NSError *)error;
@end


@interface RSFrameInterpolator : NSObject

-(id)initWithInput:(NSURL *)input output:(NSURL *)output;

-(void)interpolateAsynchronously;

@property Class<RSIInterpolationCompositing> customCompositor;
@property (weak) id<RSFrameInterpolatorDelegate> delegate;

@end
