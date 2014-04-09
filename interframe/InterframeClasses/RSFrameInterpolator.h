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
#import "RSFrameInterpolationState.h"

@class RSFrameInterpolator;

@protocol RSFrameInterpolatorDelegate <NSObject>
-(void)interpolatorFinished:(RSFrameInterpolator *)interpolator;
@end

@protocol RSFrameInterpolatorSource <NSObject>
-(CGImageRef)newInterpolatedImageForInterpolator:(RSFrameInterpolator *)interpolator
                                       withState:(RSFrameInterpolationState *)state;
@end


@interface RSFrameInterpolator : NSObject

-(id)initWithAsset:(AVAsset *)asset output:(NSURL *)output;

-(void)interpolate;

@property CGImageRef placeholderInterpolatedImage;

@property (weak) id<RSFrameInterpolatorDelegate> delegate;
@property (weak) id<RSFrameInterpolatorSource> source;

@end
