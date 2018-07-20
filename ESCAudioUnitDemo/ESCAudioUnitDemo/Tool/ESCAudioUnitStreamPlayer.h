//
//  ESCAudioUnitStreamPlayer.h
//  ESCAudioUnitDemo
//
//  Created by xiang on 2018/7/20.
//  Copyright © 2018年 xiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface ESCAudioUnitStreamPlayer : NSObject

- (instancetype)initWithSampleRate:(NSInteger)sampleRate
                          formatID:(AudioFormatID)formatID
                       formatFlags:(AudioFormatFlags)formatFlags
                  channelsPerFrame:(NSInteger)channelsPerFrame
                    bitsPerChannel:(NSInteger)bitsPerChannel
                   framesPerPacket:(NSInteger)framesPerPacket;

- (void)play:(NSData *)data;

- (void)stop;

@end
