//
//  ViewController.m
//  ESCAudioUnitDemo
//
//  Created by xiang on 2018/7/20.
//  Copyright © 2018年 xiang. All rights reserved.
//

#import "ViewController.h"
#import "ESCAudioUnitPlayer.h"
#import "ESCAudioUnitRecorder.h"
#import "ESCAudioUnitStreamPlayer.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()<ESCAudioUnitRecorderDelegate> {
    
}

@property(nonatomic,strong)ESCAudioUnitRecorder* audioUnitRecorder;

@property(nonatomic,strong)ESCAudioUnitPlayer* mp3Player;

@property(nonatomic,strong)NSMutableData* temData;

@property(nonatomic,strong)AVAudioPlayer* audioPlayer;

@property(nonatomic,strong)ESCAudioUnitStreamPlayer* unitStreamPlayer;

@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (IBAction)didClickPlayLocalMp3File:(id)sender {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"G.E.M.邓紫棋 - 喜欢你.mp3" ofType:nil];
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
    self.unitStreamPlayer = [[ESCAudioUnitStreamPlayer alloc] initWithSampleRate:44100 formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked channelsPerFrame:2 bitsPerChannel:16 framesPerPacket:1];
    NSString *pcmFilePath = [[NSBundle mainBundle] pathForResource:@"vocal.pcm" ofType:nil];
    
//    self.unitStreamPlayer = [[ESCAudioUnitStreamPlayer alloc] initWithSampleRate:8000 formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked channelsPerFrame:1 bitsPerChannel:16 framesPerPacket:1];
//        NSString *pcmFilePath = [[NSBundle mainBundle] pathForResource:@"1708101114545.pcm" ofType:nil];
    
    
    NSData *pcmData = [NSData dataWithContentsOfFile:pcmFilePath];
    NSInteger count = pcmData.length / 1000;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        for (int i = 0; i < count; i++) {
            NSInteger lenth = pcmData.length / count;
            NSData *pcmDatarange = [pcmData subdataWithRange:NSMakeRange(i * lenth, lenth)];
//            NSLog(@"encode buffer %d==%d",i,lenth);
            [self.unitStreamPlayer play:pcmDatarange];
        }
        //模拟中断
//                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
//                    for (int i = 0; i < count; i++) {
//                        NSInteger lenth = pcmData.length / count;
//                        NSData *pcmDatarange = [pcmData subdataWithRange:NSMakeRange(i * lenth, lenth)];
//                        //            NSLog(@"encode buffer %d==%d",i,lenth);
//                        [self.unitStreamPlayer play:pcmDatarange];
//
//                    }
//                });
    });
}
- (IBAction)didClickStopPlayPCMStreamButton:(id)sender {
    [self.unitStreamPlayer stop];
}

- (IBAction)didClickRecordFileStreamButton:(id)sender {
    
}

- (IBAction)didClickStopRecordButton:(id)sender {
 
}

- (IBAction)didClickPlayRecordStreamButton:(id)sender {
}

- (IBAction)didClickStopPlayRecordStreamButton:(id)sender {
    
}
- (IBAction)didClickAtSameTimeRecorderAndPlayPCMButton:(id)sender {
    if (self.audioUnitRecorder == nil) {
        self.audioUnitRecorder = [[ESCAudioUnitRecorder alloc] initWithSampleRate:20000 formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked channelsPerFrame:1 bitsPerChannel:16 framesPerPacket:1];
        self.audioUnitRecorder.delegate = self;
        [self.audioUnitRecorder startRecordToStream];
        self.unitStreamPlayer = [[ESCAudioUnitStreamPlayer alloc] initWithSampleRate:20000 formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked channelsPerFrame:1 bitsPerChannel:16 framesPerPacket:1];
    }
}
- (IBAction)didClickStopRecorderAndPlayPCMButton:(id)sender {
    [self.audioUnitRecorder stopRecordToStream];
    [self.unitStreamPlayer stop];
    self.audioUnitRecorder = nil;
    self.unitStreamPlayer = nil;
}

#pragma mark - ESCAudioUnitRecorderDelegate
- (void)ESCAudioUnitRecorderReceivedAudioData:(NSData *)data {
    [self.unitStreamPlayer  play:data];
}

@end
