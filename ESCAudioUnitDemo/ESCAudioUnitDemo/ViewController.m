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
#import "ESCAudioUnitRecorder.h"


@interface ViewController ()<ESCAudioUnitRecorderDelegate> {
    
}

@property(nonatomic,strong)ESCAudioUnitRecorder* audioUnitRecorder;

@property(nonatomic,strong)ESCAudioUnitPlayer* mp3Player;

@property(nonatomic,strong)AudioHandler* audioHandler;

@property(nonatomic,strong)ESCAudioStreamPlayer *streamPlayer;

@property(nonatomic,strong)NSMutableData* temData;

@property(nonatomic,strong)AVAudioPlayer* audioPlayer;

@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
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
    self.streamPlayer = [[ESCAudioStreamPlayer alloc] initWithSampleRate:44100 formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked channelsPerFrame:2 bitsPerChannel:16 framesPerPacket:1];
    NSString *pcmFilePath = [[NSBundle mainBundle] pathForResource:@"vocal.pcm" ofType:nil];
    
//        self.streamPlayer = [[ESCAudioStreamPlayer alloc] initWithSampleRate:8000 formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked channelsPerFrame:1 bitsPerChannel:16 framesPerPacket:1];
//        NSString *pcmFilePath = [[NSBundle mainBundle] pathForResource:@"1708101114545.pcm" ofType:nil];
    //
    
    [self.audioHandler start:AU_op_Listen audioFormat:1];
    
    NSData *pcmData = [NSData dataWithContentsOfFile:pcmFilePath];
    NSInteger count = 100;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        for (int i = 0; i < count; i++) {
            NSInteger lenth = pcmData.length / count;
            NSData *pcmDatarange = [pcmData subdataWithRange:NSMakeRange(i * lenth, lenth)];
            //            NSLog(@"encode buffer %d==%d",i,lenth);
            [self.streamPlayer play:pcmDatarange];
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
    [self.streamPlayer stop];
}

- (IBAction)didClickRecordFileStreamButton:(id)sender {
    if (self.audioUnitRecorder == nil) {
        self.audioUnitRecorder = [[ESCAudioUnitRecorder alloc] initWithSampleRate:8000 formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked channelsPerFrame:1 bitsPerChannel:16 framesPerPacket:1];
        self.audioUnitRecorder.delegate = self;
        [self.audioUnitRecorder startRecordToStream];
        self.streamPlayer = [[ESCAudioStreamPlayer alloc] initWithSampleRate:8000 formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked channelsPerFrame:1 bitsPerChannel:16 framesPerPacket:1];
    }
}

- (IBAction)didClickStopRecordButton:(id)sender {
    [self.audioUnitRecorder stopRecordToStream];
    [self.streamPlayer stop];
    self.audioUnitRecorder = nil;
    self.streamPlayer = nil;
}

- (IBAction)didClickPlayRecordStreamButton:(id)sender {
}

- (IBAction)didClickStopPlayRecordStreamButton:(id)sender {
}

#pragma mark - ESCAudioUnitRecorderDelegate
- (void)ESCAudioUnitRecorderReceivedAudioData:(NSData *)data {
    [self.streamPlayer play:data];
}

@end
