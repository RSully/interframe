//
//  RSUpconverter.h
//  interframe
//
//  Created by Ryan Sullivan on 4/7/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "RSFrameInterpolationState.h"

@class RSFrameInterpolator;

@protocol RSFrameInterpolatorDelegate <NSObject>
-(CGImageRef)createInterpolatedImageForInterpolator:(RSFrameInterpolator *)interpolator
                                          withState:(RSFrameInterpolationState *)state;
-(void)interpolatorFinished:(RSFrameInterpolator *)interpolator;
@end


@interface RSFrameInterpolator : NSObject

-(id)initWithAsset:(AVAsset *)asset output:(NSURL *)output;

-(void)interpolate;

@property CGImageRef placeholderInterpolatedImage;

@property (weak) id<RSFrameInterpolatorDelegate> delegate;

@end
