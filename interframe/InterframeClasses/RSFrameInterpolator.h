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

@class RSFrameInterpolator;

@protocol RSFrameInterpolatorDelegate <NSObject>
-(void)interpolatorFinished:(RSFrameInterpolator *)interpolator;
@end


@interface RSFrameInterpolator : NSObject <AVVideoCompositionValidationHandling>

-(id)initWithAsset:(AVAsset *)asset output:(NSURL *)output compositor:(Class<AVVideoCompositing>)compositor;

-(void)interpolate;

@property (weak) id<RSFrameInterpolatorDelegate> delegate;

@end
