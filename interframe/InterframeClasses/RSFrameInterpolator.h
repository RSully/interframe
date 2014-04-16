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
-(void)interpolatorFailed:(RSFrameInterpolator *)interpolator withError:(NSError *)error;
@end


@interface RSFrameInterpolator : NSObject

-(id)initWithAsset:(AVAsset *)asset;

-(void)interpolateToOutput:(NSURL *)output;

@property (strong) Class<AVVideoCompositing> customCompositor;
@property (weak) id<RSFrameInterpolatorDelegate> delegate;

@end
