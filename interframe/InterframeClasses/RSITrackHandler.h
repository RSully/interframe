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

@property (strong) AVAssetReaderOutput *readerOutput;

@property (strong) AVAssetWriterInput *writerInput;

@end
