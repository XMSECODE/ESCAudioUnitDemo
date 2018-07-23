//
//  ESCAudioUnitStreamPlayer.m
//  ESCAudioUnitDemo
//
//  Created by xiang on 2018/7/20.
//  Copyright © 2018年 xiang. All rights reserved.
//

#import "ESCAudioUnitStreamPlayer.h"
#import <AVFoundation/AVFoundation.h>

//播放的element
static int play_element = 0;


@interface ESCAudioUnitStreamPlayer() {
    AudioStreamBasicDescription audioDescription;///音频参数
    AudioUnit audioUnit;
    AudioBufferList *buffList;
}

@property(nonatomic,strong)NSMutableArray* cachDataArray;

@property(nonatomic,assign)BOOL isFirstPlay;

@property(nonatomic,assign)NSInteger currentPlayIndex;

@end

@implementation ESCAudioUnitStreamPlayer

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
        self.cachDataArray = [NSMutableArray array];
        self.isFirstPlay = YES;
    }
    return self;
}

- (void)play:(NSData *)data {
    [self.cachDataArray addObject:data];
    if (self.isFirstPlay) {
        AudioOutputUnitStart(audioUnit);
        self.isFirstPlay = NO;
    }
}

- (NSData *)getLenthDataFromCachData:(NSInteger)lenth {
    NSInteger getLenth = 0;
    NSMutableData *getData = [NSMutableData data];
    while (1) {
        if (self.cachDataArray.count <= 0) {
            break;
        }
        NSData *firstData = self.cachDataArray.firstObject;
        if (firstData.length + getLenth >= lenth) {
            if (firstData.length == lenth - getLenth) {
                [getData appendData:firstData];
                [self.cachDataArray removeObject:firstData];
            }else {
                NSData *rangeData = [firstData subdataWithRange:NSMakeRange(0, lenth - getLenth)];
                [getData appendData:rangeData];
                NSData *otherData = [firstData subdataWithRange:NSMakeRange(lenth - getLenth, firstData.length - (lenth - getLenth))];
                self.cachDataArray[0] = otherData;
            }
            break;
        }else {
            [getData appendData:firstData];
            [self.cachDataArray removeObject:firstData];
            getLenth += firstData.length;
        }
    }
    
    
    return getData;
}

- (void)stop {
    AudioOutputUnitStop(audioUnit);
    [self audio_release];
}

OSStatus PlayCallback(void *inRefCon,
                      AudioUnitRenderActionFlags *ioActionFlags,
                      const AudioTimeStamp *inTimeStamp,
                      UInt32 inBusNumber,
                      UInt32 inNumberFrames,
                      AudioBufferList *ioData) {
    
    ESCAudioUnitStreamPlayer *player = (__bridge ESCAudioUnitStreamPlayer *)(inRefCon);
    if (player.cachDataArray.count > 0) {
        
//        NSData *playData = player.cachDataArray.firstObject;
        
//        NSData *pcmDatarange = [playData subdataWithRange:NSMakeRange(player.currentPlayIndex, ioData->mBuffers[0].mDataByteSize)];
        NSData *pcmDatarange = [player getLenthDataFromCachData:ioData->mBuffers[0].mDataByteSize];
//        player.currentPlayIndex+= ioData->mBuffers[0].mDataByteSize;

        const void *palydata = [pcmDatarange bytes];

        memcpy(ioData->mBuffers[0].mData, palydata, pcmDatarange.length);
        
        AudioUnitRender(player->audioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
        
    }else {
        
    }
  
    return noErr;
}

- (void)initRemoteIO {
    [self initAudioSession];
    
    [self initAudioComponent];
    
    [self initBuffer];
    
    [self initAudioProperty];
    
    [self initFormat];
    
    [self initPlayCallback];
    
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
                                           play_element,
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

- (void)initAudioProperty {
    UInt32 flag = 1;
    OSStatus status;
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  play_element,
                                  &flag,
                                  sizeof(flag));
    if (status != noErr) {
        NSLog(@"set in put enableio failed!");
    }
}

- (void)initFormat {
    OSStatus status;
    status = AudioUnitSetParameter(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, play_element, kAudioUnitSubType_VoiceProcessingIO, kAudioUnitSubType_VoiceProcessingIO);
    
    if (status != noErr) {
        NSLog(@"SetParameter failed！");
    }
    
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  play_element,
                                  &audioDescription,
                                  sizeof(audioDescription));
    if (status != noErr) {
        NSLog(@"set out put format failed!  %d",status);
    }
}

- (void)initPlayCallback {
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Global,
                         play_element,
                         &playCallback,
                         sizeof(playCallback));
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
