//
//  ESCAudioUnitRecorder.h
//  ESCAudioUnitDemo
//
//  Created by xiang on 2018/7/20.
//  Copyright © 2018年 xiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface ESCAudioUnitRecorder : NSObject

- (instancetype)initWithSampleRate:(NSInteger)sampleRate
                          formatID:(AudioFormatID)formatID
                       formatFlags:(AudioFormatFlags)formatFlags
                  channelsPerFrame:(NSInteger)channelsPerFrame
                    bitsPerChannel:(NSInteger)bitsPerChannel
                   framesPerPacket:(NSInteger)framesPerPacket;

- (void)startRecordToFilePath:(NSString *)filePath;
- (void)stopRecordToFile;

- (void)startRecordToStream;
- (void)stopRecordToStream;

@end
