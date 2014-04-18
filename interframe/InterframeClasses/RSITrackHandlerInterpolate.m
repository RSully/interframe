//
//  RSITrackHandlerInterpolate.m
//  interframe
//
//  Created by Ryan Sullivan on 4/17/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import "RSITrackHandlerInterpolate.h"

@interface RSITrackHandlerInterpolate ()

@property (strong) id<AVVideoCompositing> compositor;

@end


@implementation RSITrackHandlerInterpolate

-(id)initWithInputTrack:(AVAssetTrack *)inputTrack compositor:(id<AVVideoCompositing>)compositor
{
    NSDictionary *readerSettings = [compositor sourcePixelBufferAttributes];

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

    if ((self = [self _initWithInputTrack:inputTrack readerSettings:readerSettings writerSettings:nil]))
    {
        self.compositor = compositor;
    }
    return self;
}

-(void)_mediaDataRequested {
    NSLog(@"-mediaDataRequested %@", self);
    [self markAsFinished];
}

@end
