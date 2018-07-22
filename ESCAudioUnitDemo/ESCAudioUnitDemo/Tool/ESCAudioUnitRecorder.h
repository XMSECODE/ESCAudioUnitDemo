//
//  ESCAudioUnitRecorder.h
//  ESCAudioUnitDemo
//
//  Created by xiang on 2018/7/20.
//  Copyright © 2018年 xiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol ESCAudioUnitRecorderDelegate <NSObject>

- (void)ESCAudioUnitRecorderReceivedAudioData:(NSData *)data;

@end

@interface ESCAudioUnitRecorder : NSObject

@property(nonatomic,weak)id<ESCAudioUnitRecorderDelegate> delegate;

- (instancetype)initWithSampleRate:(NSInteger)sampleRate
                          formatID:(AudioFormatID)formatID
                       formatFlags:(AudioFormatFlags)formatFlags
                  channelsPerFrame:(NSInteger)channelsPerFrame
                    bitsPerChannel:(NSInteger)bitsPerChannel
                   framesPerPacket:(NSInteger)framesPerPacket;

- (void)startRecordToStream;
- (void)stopRecordToStream;

@end
