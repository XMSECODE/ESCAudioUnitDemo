//
//  ESCAudioUnitStreamPlayer.m
//  ESCAudioUnitDemo
//
//  Created by xiang on 2018/7/20.
//  Copyright © 2018年 xiang. All rights reserved.
//

#import "ESCAudioUnitStreamPlayer.h"
#import <AVFoundation/AVFoundation.h>




@interface ESCAudioUnitStreamPlayer() {
    
}

@end

@implementation ESCAudioUnitStreamPlayer

- (instancetype)initWithSampleRate:(NSInteger)sampleRate
                          formatID:(AudioFormatID)formatID
                       formatFlags:(AudioFormatFlags)formatFlags
                  channelsPerFrame:(NSInteger)channelsPerFrame
                    bitsPerChannel:(NSInteger)bitsPerChannel
                   framesPerPacket:(NSInteger)framesPerPacket {
    if (self = [super init]) {
        
    }
    return self;
}

- (void)play:(NSData *)data {
}

- (void)stop {
    
}

@end
