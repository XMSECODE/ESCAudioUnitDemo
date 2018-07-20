//
//  ViewController.m
//  ESCAudioUnitDemo
//
//  Created by xiang on 2018/7/20.
//  Copyright © 2018年 xiang. All rights reserved.
//

#import "ViewController.h"
#import "ESCAudioUnitPlayer.h"
#import "AudioHandler.h"
#import "ESCAudioStreamPlayer.h"

//#define INPUT_BUS 0;
static int INPUT_BUS = 0;
static int OUTPUT_BUS = 1;

static AudioUnit audioUnit;
static AudioBufferList *buffList;

@interface ViewController () {
    
}

@property(nonatomic,strong)ESCAudioUnitPlayer* mp3Player;

@property(nonatomic,strong)AudioHandler* audioHandler;

@property(nonatomic,strong)ESCAudioStreamPlayer *streamPlayer;

@end

@implementation ViewController


 OSStatus RecordCallback(    void *                            inRefCon,
                    AudioUnitRenderActionFlags *    ioActionFlags,
                    const AudioTimeStamp *            inTimeStamp,
                    UInt32                            inBusNumber,
                    UInt32                            inNumberFrames,
                         AudioBufferList * __nullable    ioData);
OSStatus PlayCallback(    void *                            inRefCon,
                    AudioUnitRenderActionFlags *    ioActionFlags,
                    const AudioTimeStamp *            inTimeStamp,
                    UInt32                            inBusNumber,
                    UInt32                            inNumberFrames,
                      AudioBufferList * __nullable    ioData);


- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    
//    [self initRemoteIO];
    
}

- (void)initRemoteIO {
    AudioUnitInitialize(audioUnit);
    [self initAudioSession];
    
    [self initBuffer];
    
    [self initAudioComponent];
    
    [self initFormat];
    
    [self initAudioProperty];
    
    [self initRecordeCallback];
    
    [self initPlayCallback];
}

- (void)initAudioSession {
    NSError *error;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    [audioSession setPreferredSampleRate:44100 error:&error];
    [audioSession setPreferredInputNumberOfChannels:1 error:&error];
    [audioSession setPreferredOutputNumberOfChannels:1 error:&error];
    [audioSession setPreferredIOBufferDuration:0.022 error:&error];
}

- (void)initBuffer {
    UInt32 flag = 0;
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_ShouldAllocateBuffer,
                         kAudioUnitScope_Output,
                         INPUT_BUS,
                         &flag,
                         sizeof(flag));
    
    buffList = (AudioBufferList*)malloc(sizeof(AudioBufferList));
    buffList->mNumberBuffers = 1;
    buffList->mBuffers[0].mNumberChannels = 1;
    buffList->mBuffers[0].mDataByteSize = 2048 * sizeof(short);
    buffList->mBuffers[0].mData = (short *)malloc(sizeof(short) * 2048);
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

- (void)initFormat {
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = 44100;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mChannelsPerFrame = 1;
    audioFormat.mBitsPerChannel = 16;
    audioFormat.mBytesPerFrame = audioFormat.mBitsPerChannel * audioFormat.mChannelsPerFrame / 8;
    audioFormat.mBytesPerPacket = audioFormat.mBytesPerFrame * audioFormat.mFramesPerPacket;
//    audioFormat.mBytesPerFrame = 2;
//    audioFormat.mBytesPerPacket= 2;
    self.streamPlayer = [[ESCAudioStreamPlayer alloc] initWithSampleRate:audioFormat.mSampleRate formatID:audioFormat.mFormatID formatFlags:audioFormat.mFormatFlags channelsPerFrame:audioFormat.mChannelsPerFrame bitsPerChannel:audioFormat.mBitsPerChannel framesPerPacket:audioFormat.mFramesPerPacket];
    
    OSStatus status = AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         INPUT_BUS,
                         &audioFormat,
                         sizeof(audioFormat));
    status = AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &audioFormat,
                         sizeof(audioFormat));
}

- (void)initRecordeCallback {
    AURenderCallbackStruct recordCallback;
    recordCallback.inputProc = RecordCallback;
    recordCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(audioUnit,
                         kAudioOutputUnitProperty_SetInputCallback,
                         kAudioUnitScope_Global,
                         INPUT_BUS,
                         &recordCallback,
                         sizeof(recordCallback));
}

- (void)initPlayCallback {
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Global,
                         OUTPUT_BUS,
                         &playCallback,
                         sizeof(playCallback));
}

- (void)initAudioProperty {
    UInt32 flag = 1;
    
    AudioUnitSetProperty(audioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,
                         INPUT_BUS,
                         &flag,
                         sizeof(flag));
    AudioUnitSetProperty(audioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &flag,
                         sizeof(flag));
    
}

#pragma mark - callback function

 OSStatus RecordCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData)
{
    ViewController *viewController = (__bridge ViewController *)(inRefCon);
    
    AudioUnitRender(audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, buffList);
    
    NSLog(@"size1 = %d", buffList->mBuffers[0].mDataByteSize);
    
    NSData *data = [NSData dataWithBytes:buffList->mBuffers[0].mData length:buffList->mBuffers[0].mDataByteSize];
    [viewController.streamPlayer play:data];
    
    return noErr;
}

 OSStatus PlayCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    NSLog(@"size2 = %d", ioData->mBuffers[0].mDataByteSize);
    memcpy(ioData->mBuffers[0].mData, buffList->mBuffers[0].mData, ioData->mBuffers[0].mDataByteSize);
    AudioUnitRender(audioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, buffList);
    
    return noErr;
}

#pragma mark - public methods

- (void)startRecorder {
    [ self initRemoteIO];
    AudioOutputUnitStart(audioUnit);
}

- (void)stopRecorder {
    
    AudioOutputUnitStop(audioUnit);
    [self audio_release];
}

- (void)audio_release {
    //    [[NSNotificationCenter defaultCenter] removeObserver:self];
    //    AudioOutputUnitStop(audioUnit);
    //    AudioComponentInstanceDispose(audioUnit);
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
    AudioUnitUninitialize(audioUnit);
}




- (IBAction)didClickPlayLocalMp3File:(id)sender {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"Bridge - 雾都历.mp3" ofType:nil];
    ESCAudioUnitPlayer *player = [[ESCAudioUnitPlayer alloc] initWithFilePath:filePath];
    [player startPlay];
    self.mp3Player = player;
}

- (IBAction)didClickPausePlayLocalMp3File:(id)sender {
    [self.mp3Player pause];
}

- (IBAction)didClickStopPlayLocalMp3File:(id)sender {
    [self.mp3Player stop];
}

- (IBAction)didClickPlayPCMStreamButton:(id)sender {
    self.audioHandler = [[AudioHandler alloc] init];
//    self.streamPlayer = [[ESCAudioStreamPlayer alloc] initWithSampleRate:44100 formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked channelsPerFrame:2 bitsPerChannel:16 framesPerPacket:1];
    NSString *pcmFilePath = [[NSBundle mainBundle] pathForResource:@"vocal.pcm" ofType:nil];
    
    //    self.streamPlayer = [[ESCAudioStreamPlayer alloc] initWithSampleRate:8000 formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked channelsPerFrame:1 bitsPerChannel:16];
    //    NSString *pcmFilePath = [[NSBundle mainBundle] pathForResource:@"1708101114545.pcm" ofType:nil];
    //
    
    [self.audioHandler start:AU_op_Listen audioFormat:1];
    
    NSData *pcmData = [NSData dataWithContentsOfFile:pcmFilePath];
    NSInteger count = 100;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        for (int i = 0; i < count; i++) {
            NSInteger lenth = pcmData.length / count;
            NSData *pcmDatarange = [pcmData subdataWithRange:NSMakeRange(i * lenth, lenth)];
            //            NSLog(@"encode buffer %d==%d",i,lenth);
//            [self.streamPlayer play:pcmDatarange];
            [self.audioHandler receiverAudio:pcmDatarange.bytes WithLen:pcmDatarange.length];
        }
        //模拟中断
        //        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
        //            for (int i = 0; i < count; i++) {
        //                NSInteger lenth = pcmData.length / count;
        //                NSData *pcmDatarange = [pcmData subdataWithRange:NSMakeRange(i * lenth, lenth)];
        //                //            NSLog(@"encode buffer %d==%d",i,lenth);
        //                [self.streamPlayer play:pcmDatarange];
        //
        //            }
        //        });
    });
}
- (IBAction)didClickStopPlayPCMStreamButton:(id)sender {
}

- (IBAction)didClickRecordFileStreamButton:(id)sender {
    [self startRecorder];
}
- (IBAction)didClickStopRecordButton:(id)sender {
}
- (IBAction)didClickPlayRecordStreamButton:(id)sender {
}
- (IBAction)didClickStopPlayRecordStreamButton:(id)sender {
}

@end
