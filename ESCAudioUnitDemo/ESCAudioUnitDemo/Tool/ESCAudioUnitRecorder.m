//
//  ESCAudioUnitRecorder.m
//  ESCAudioUnitDemo
//
//  Created by xiang on 2018/7/20.
//  Copyright © 2018年 xiang. All rights reserved.
//

#import "ESCAudioUnitRecorder.h"
#import <AVFoundation/AVFoundation.h>

//录音为1--接触到outscope
static int record_element = 1;

@interface ESCAudioUnitRecorder () {
    AudioStreamBasicDescription audioDescription;///音频参数
    AudioUnit audioUnit;
    AudioBufferList *buffList;
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
        audioDescription.mSampleRate              = sampleRate;//采样率
        audioDescription.mFormatID                = formatID;
        audioDescription.mFormatFlags             = formatFlags;
        audioDescription.mChannelsPerFrame        = (UInt32)channelsPerFrame;///单声道
        audioDescription.mFramesPerPacket         = (UInt32)framesPerPacket;//每一个packet一侦数据
        audioDescription.mBitsPerChannel          = (UInt32)bitsPerChannel;//每个采样点16bit量化
        audioDescription.mBytesPerFrame           = (audioDescription.mBitsPerChannel / 8) * audioDescription.mChannelsPerFrame;
        audioDescription.mBytesPerPacket          = audioDescription.mBytesPerFrame * audioDescription.mFramesPerPacket;
        [self initRemoteIO];
    }
    return self;
}

- (void)startRecordToStream {
    AudioOutputUnitStart(audioUnit);

}

- (void)stopRecordToStream {
    AudioOutputUnitStop(audioUnit);
    [self audio_release];

}

#pragma mark - callback function
OSStatus RecordCallback(void *inRefCon,
                        AudioUnitRenderActionFlags *ioActionFlags,
                        const AudioTimeStamp *inTimeStamp,
                        UInt32 inBusNumber,
                        UInt32 inNumberFrames,
                        AudioBufferList *ioData) {
    ESCAudioUnitRecorder *audioUnitRecorder = (__bridge ESCAudioUnitRecorder *)(inRefCon);
    AudioUnitRender(audioUnitRecorder->audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, audioUnitRecorder->buffList);
    
    NSLog(@"record size = %d", audioUnitRecorder->buffList->mBuffers[0].mDataByteSize);
    
    NSData *data = [NSData dataWithBytes:audioUnitRecorder->buffList->mBuffers[0].mData length:audioUnitRecorder->buffList->mBuffers[0].mDataByteSize];
    if (audioUnitRecorder.delegate && [audioUnitRecorder.delegate respondsToSelector:@selector(ESCAudioUnitRecorderReceivedAudioData:)]) {
        [audioUnitRecorder.delegate ESCAudioUnitRecorderReceivedAudioData:data];
    }
    
    return noErr;
}

- (void)initRemoteIO {
    [self initAudioSession];
    
    [self initAudioComponent];
    
    [self initBuffer];
    
    [self initAudioProperty];
    
    [self initFormat];
    
    [self initRecordeCallback];
    
    //    [self initPlayCallback];
    
    AudioUnitInitialize(audioUnit);
    
}

- (void)initAudioSession {
    NSError *error;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    BOOL result = [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (error) {
        NSLog(@"audio session set category failed! %@",error);
    }
    result = [audioSession setPreferredSampleRate:8000 error:&error];
    if (error) {
        NSLog(@"audio session set samplerate failed! %@",error);
    }
    result = [audioSession setPreferredInputNumberOfChannels:1 error:&error];
    if (error) {
        NSLog(@"audio session set preferred failed! %@",error);
    }
    result = [audioSession setPreferredOutputNumberOfChannels:1 error:&error];
    if (error) {
        NSLog(@"audio session set ouput number channel failed! %@",error);
    }
    result = [audioSession setPreferredIOBufferDuration:0.022 error:&error];
    if (error) {
        NSLog(@"audio session set buffer duration failed! %@",error);
    }
}

- (void)initAudioComponent {
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    AudioComponentInstanceNew(inputComponent, &audioUnit);
}

- (void)initBuffer {
    UInt32 flag = 0;
    OSStatus status = AudioUnitSetProperty(audioUnit,
                                           kAudioUnitProperty_ShouldAllocateBuffer,
                                           kAudioUnitScope_Output,
                                           record_element,
                                           &flag,
                                           sizeof(flag));
    if (status != noErr) {
        NSLog(@"set buffer failed!");
    }
    
    buffList = (AudioBufferList*)malloc(sizeof(AudioBufferList));
    buffList->mNumberBuffers = 1;
    buffList->mBuffers[0].mNumberChannels = 1;
    buffList->mBuffers[0].mDataByteSize = 2048 * sizeof(short);
    buffList->mBuffers[0].mData = (short *)malloc(sizeof(short) * 2048);
}



- (void)initFormat {
    OSStatus status;
    status = AudioUnitSetParameter(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, record_element, kAudioUnitSubType_VoiceProcessingIO, kAudioUnitSubType_VoiceProcessingIO);
    
    if (status != noErr) {
        NSLog(@"SetParameter failed！");
    }
    
    //    status = AudioUnitSetProperty(audioUnit,
    //                                  kAudioUnitProperty_StreamFormat,
    //                                  kAudioUnitScope_Input,
    //                                  INPUT_BUS,
    //                                  &audioFormat,
    //                                  sizeof(audioFormat));
    //    if (status != noErr) {
    //        NSLog(@"set in put format failed!");
    //    }
    
    
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  record_element,
                                  &audioDescription,
                                  sizeof(audioDescription));
    if (status != noErr) {
        NSLog(@"set out put format failed!  %d",status);
    }
}

- (void)initRecordeCallback {
    AURenderCallbackStruct recordCallback;
    recordCallback.inputProc = RecordCallback;
    recordCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(audioUnit,
                         kAudioOutputUnitProperty_SetInputCallback,
                         kAudioUnitScope_Global,
                         record_element,
                         &recordCallback,
                         sizeof(recordCallback));
}

- (void)initPlayCallback {
    //    AURenderCallbackStruct playCallback;
    //    playCallback.inputProc = PlayCallback;
    //    playCallback.inputProcRefCon = (__bridge void *)self;
    //    AudioUnitSetProperty(audioUnit,
    //                         kAudioUnitProperty_SetRenderCallback,
    //                         kAudioUnitScope_Global,
    //                         OUTPUT_BUS,
    //                         &playCallback,
    //                         sizeof(playCallback));
}

- (void)initAudioProperty {
    UInt32 flag = 1;
    OSStatus status;
    //    status = AudioUnitSetProperty(audioUnit,
    //                         kAudioOutputUnitProperty_EnableIO,
    //                         kAudioUnitScope_Input,
    //                         INPUT_BUS,
    //                         &flag,
    //                         sizeof(flag));
    //    if (status != noErr) {
    //        NSLog(@"set in put enableio failed!");
    //    }
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  record_element,
                                  &flag,
                                  sizeof(flag));
    if (status != noErr) {
        NSLog(@"set Out put enableio failed!== %d",status);
    }
    
}


- (void)audio_release {
    AudioUnitUninitialize(audioUnit);
    if (buffList != NULL) {
        free(buffList);
        buffList = NULL;
    }
    
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    AudioOutputUnitStop(audioUnit);
    AudioComponentInstanceDispose(audioUnit);
    if (buffList != NULL) {
        free(buffList);
        buffList = NULL;
    }
}
@end
