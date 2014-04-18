//
//  RSITrackHandlerInterpolate.m
//  interframe
//
//  Created by Ryan Sullivan on 4/17/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSITrackHandlerInterpolate.h"
#import "RSIRenderContext.h"
#import "RSIInterpolationCompositing.h"

@interface RSITrackHandlerInterpolate ()

@property (strong) id<RSIInterpolationCompositing> compositor;

@property (strong) RSIRenderContext *renderContext;

@end


@implementation RSITrackHandlerInterpolate

-(id)initWithInputTrack:(AVAssetTrack *)inputTrack compositor:(id<RSIInterpolationCompositing>)compositor
{

    // Uncomment if we need format/width/height/etc.
//    CMFormatDescriptionRef formatHint = (__bridge CMFormatDescriptionRef)([inputTrack formatDescriptions][0]);
//    CMVideoCodecType formatCodec = CFSwapInt32BigToHost(CMFormatDescriptionGetMediaSubType(formatHint));
//    char formatCodecBuf[sizeof(CMVideoCodecType) + 1] = {0}; // add 1 for null terminator
//    memcpy(formatCodecBuf, &formatCodec, sizeof(CMVideoCodecType));
//    NSString *formatCodecString = @(formatCodecBuf);
//    NSDictionary *writerSettings = @{
//                                     AVVideoCodecKey: formatCodecString,
//                                     AVVideoWidthKey: @(inputTrack.naturalSize.width),
//                                     AVVideoHeightKey: @(inputTrack.naturalSize.height)
//                                     };

    if ((self = [self _initWithInputTrack:inputTrack readerSettings:[compositor sourcePixelBufferAttributes] writerSettings:nil]))
    {
        self.compositor = compositor;

        self.renderContext = [[RSIRenderContext alloc] _initWithWriterInput:self.writerInput sourceAttributes:[compositor requiredPixelBufferAttributesForRenderContext]];
        [compositor renderContextChanged:self.renderContext];
    }
    return self;
}

-(void)_mediaDataRequested {
    NSLog(@"-mediaDataRequested %@", self);
    [self markAsFinished];
}

@end
