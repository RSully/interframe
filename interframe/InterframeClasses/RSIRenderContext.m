//
//  RSIRenderContext.m
//  interframe
//
//  Created by Ryan Sullivan on 4/17/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSIRenderContext.h"

@interface RSIRenderContext ()

@property (strong) AVAssetWriterInputPixelBufferAdaptor *writerAdapter;

@end

@implementation RSIRenderContext

-(id)_initWithWriterInput:(AVAssetWriterInput *)writerInput sourceAttributes:(NSDictionary *)attributes
{
    if ((self = [self init]))
    {
        self.writerAdapter = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:writerInput
                                                                        sourcePixelBufferAttributes:attributes];
    }
    return self;
}

-(CVPixelBufferRef)newPixelBuffer {
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn status = CVPixelBufferPoolCreatePixelBuffer(NULL, self.writerAdapter.pixelBufferPool, &pixelBuffer);

    if (status != kCVReturnSuccess)
    {
        NSLog(@"Failed to create pixel buffer (%d)", status);
        return NULL;
    }

    return pixelBuffer;
}

@end
