//
//  ESCAudioUnitRecorder.m
//  ESCAudioUnitDemo
//
//  Created by xiang on 2018/7/20.
//  Copyright © 2018年 xiang. All rights reserved.
//

#import "ESCAudioUnitRecorder.h"
#import <AVFoundation/AVFoundation.h>

@interface ESCAudioUnitRecorder () {
    AudioStreamBasicDescription audioDescription;///音频参数

}

@end

@implementation ESCAudioUnitRecorder

- (instancetype)initWithSampleRate:(NSInteger)sampleRate
                          formatID:(AudioFormatID)formatID
                       formatFlags:(AudioFormatFlags)formatFlags
                  channelsPerFrame:(NSInteger)channelsPerFrame
                    bitsPerChannel:(NSInteger)bitsPerChannel
                   framesPerPacket:(NSInteger)framesPerPacket {
    if (self = [super init]) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        NSError *sessionError;
        [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionError];
        NSTimeInterval bufferDuration = 0.002;
        [session setPreferredIOBufferDuration:bufferDuration error:&sessionError];
        
        [session setPreferredSampleRate:sampleRate error:&sessionError];
        
        if (session == nil) {
            NSLog(@"Error creating session: %@",[sessionError description]);
        }else{
            [session setActive:YES error:nil];
        }
        
        //创建方式1
//        {
//            //创建类型描述
//            AudioComponentDescription ioUnitDescription;
//            ioUnitDescription.componentType = kAudioUnitType_Output;
//            ioUnitDescription.componentSubType = kAudioUnitSubType_RemoteIO;
//            ioUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
//            ioUnitDescription.componentFlags = 0;
//            ioUnitDescription.componentFlagsMask = 0;
//            //创建组件
//            AudioComponent ioUnitRef = AudioComponentFindNext(NULL, &ioUnitDescription);
//            AudioUnit ioUnitInstance;
//            //创建AudioUnit
//            AudioComponentInstanceNew(ioUnitRef, &ioUnitInstance);
//        }
        //创建方式2(扩展性更强)
        {
            //创建类型描述
            AudioComponentDescription ioUnitDescription;
            ioUnitDescription.componentType = kAudioUnitType_Output;
            ioUnitDescription.componentSubType = kAudioUnitSubType_RemoteIO;
            ioUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
            ioUnitDescription.componentFlags = 0;
            ioUnitDescription.componentFlagsMask = 0;
            
            AUGraph processingGraph;
            NewAUGraph(&processingGraph);
            
            AUNode ioNode;
            AUGraphAddNode(processingGraph, &ioUnitDescription, &ioNode);
            
            AUGraphOpen(processingGraph);
            
            AudioUnit ioUnit;
            AUGraphNodeInfo(processingGraph, ioNode, NULL, &ioUnit);
            
            OSStatus status = noErr;
            UInt32 oneFlag = 1;
            UInt32 busZero = 0;
            //连接硬件
            status = AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, busZero, &oneFlag, sizeof(oneFlag));
            if (status != 0) {
                NSLog(@"Could not connect to speaker");
            }
            
            //启动麦克风
            UInt32 busOne = 1;
            AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, busOne, &oneFlag, sizeof(oneFlag));
            
            UInt32 bytesPerSample = sizeof(Float32);
            AudioStreamBasicDescription asbd;
            
            
            //设置参数
            
            audioDescription.mSampleRate              = sampleRate;//采样率
            audioDescription.mFormatID                = formatID;
            audioDescription.mFormatFlags             = formatFlags;
            audioDescription.mChannelsPerFrame        = channelsPerFrame;///单声道
            audioDescription.mFramesPerPacket         = framesPerPacket;//每一个packet一侦数据
            audioDescription.mBitsPerChannel          = bitsPerChannel;//每个采样点16bit量化
            audioDescription.mBytesPerFrame           = (audioDescription.mBitsPerChannel / 8) * audioDescription.mChannelsPerFrame;
            audioDescription.mBytesPerPacket          = audioDescription.mBytesPerFrame * audioDescription.mFramesPerPacket;
            //设置属性
            AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &audioDescription, sizeof(audioDescription));
//            self.audioFormat = [[AVAudioFormat alloc] initWithStreamDescription:&(audioDescription)];
            
            //初始化buffer
        }
        
        
        
    }
    return self;
}

- (void)startRecordToFilePath:(NSString *)filePath {
    
}

- (void)stopRecordToFile {
    
}

- (void)startRecordToStream {
    
}

- (void)stopRecordToStream {
    
}

@end
