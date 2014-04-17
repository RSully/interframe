//
//  RSITrackHandler.h
//  interframe
//
//  Created by Ryan Sullivan on 4/17/14.
//  Copyright (c) 2014 RSully. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface RSITrackHandler : NSObject

-(id)_initWithInputTrack:(AVAssetTrack *)inputTrack readerSettings:(NSDictionary *)readerSettings writerSettings:(NSDictionary *)writerSettings;

@property (strong, readonly) AVAssetTrack *inputTrack;

@property (strong, readonly) AVAssetReaderOutput *readerOutput;
@property (strong, readonly) AVAssetWriterInput *writerInput;

@end
