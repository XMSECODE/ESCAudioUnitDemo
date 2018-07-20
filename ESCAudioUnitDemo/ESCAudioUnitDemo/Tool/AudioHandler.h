//
//  AudioHandler.h
//  PBRecPlayer
//
//  Created by Partho Biswas on 10/13/14.
//  Copyright (c) 2014 Partho Biswas All rights reserved.
//

@protocol AudioControllerDelegate;

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudioTypes.h>

#import <AVFoundation/AVFoundation.h>

@class AudioHandler;
typedef  enum{
    AU_op_Listen=1,
    AU_op_Speak,
    AU_op_ListenAndSpeak,
}AU_OPTYPE;
@protocol AudioControllerDelegate <NSObject>

@optional
- (void) recordedRTP:(Byte *)rtpData andLenght:(int)len;
-(void) onRecordBufferReady:(NSData*)data;
@end



@interface AudioHandler : NSObject {
	AudioComponentInstance audioUnit;
	AudioBuffer tempBuffer; // this will hold the latest data from the microphone

    NSMutableData *fileData,*fileData2;
    int m_opType;
    int _audioFormat;
}

@property (readonly) AudioComponentInstance audioUnit;
@property (readonly) AudioBuffer tempBuffer;

@property (nonatomic, weak) id<AudioControllerDelegate> audioDelegate;

@property(nonatomic, readwrite) bool isRecordDataPullingThreadRunning, isAudioUnitRunning;
@property(nonatomic, readwrite) bool isLocalRingBackToneEnabled;
@property(nonatomic, readwrite) bool isLocalRingToneEnabled;
@property(nonatomic, readwrite) bool isBufferClean;

- (void) start: (AU_OPTYPE)opType audioFormat:(int)v_audioFormat;
- (void) stop: (AU_OPTYPE)opType;
- (void) processAudio: (AudioBufferList*) bufferList;
- (void) receiverAudio:(Byte *) audio WithLen:(int)len;

@end





