//
//  RSIInterpolationCompositing.h
//  interframe
//
//  Created by Ryan Sullivan on 4/17/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSIRenderContext.h"

/**
 * Inspired by AVVideoCompositing
 */

@protocol RSIInterpolationCompositing <NSObject>

@required

@property (nonatomic, readonly) NSDictionary *sourcePixelBufferAttributes;
@property (nonatomic, readonly) NSDictionary *requiredPixelBufferAttributesForRenderContext;

- (void)renderContextChanged:(RSIRenderContext *)newRenderContext;

- (void)startVideoCompositionRequest:(id)asyncVideoCompositionRequest;


@optional

- (void)cancelAllPendingVideoCompositionRequests;

@end
