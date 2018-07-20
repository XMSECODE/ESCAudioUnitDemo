//
//  AudioHandler.m
//  PBRecPlayer
//
//  Created by Partho Biswas on 10/13/14.
//  Copyright (c) 2014 Partho Biswas All rights reserved.
//

#import "AudioHandler.h"
#import <AudioToolbox/AudioToolbox.h>

#define kOutputBus 0
#define kInputBus 1

void checkStatus(int status){
	if (status) {
		printf("Status not 0! %d\n", status);
	}
}

@implementation AudioHandler

@synthesize audioUnit, tempBuffer, audioDelegate, isRecordDataPullingThreadRunning, isAudioUnitRunning, isBufferClean;

short shortArray[1024];
short receivedShort[2048];
NSThread* recorderThread;

static AudioHandler *sharedInstance = nil;

/**
 Initialize the audioUnit and allocate our own temporary buffer.
 The temporary buffer will hold the latest data coming in from the microphone,
 and will be copied to the output when this is requested.
 */
- (id)init {
    if ((self = [super init])) {
        OSStatus status;
        
        // Describe audio component
        AudioComponentDescription desc;
        desc.componentType = kAudioUnitType_Output;
        desc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
        desc.componentFlags = 0;
        desc.componentFlagsMask = 0;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        
        // Get component
        AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
        
        // Get audio units
        status = AudioComponentInstanceNew(inputComponent, &audioUnit);
        checkStatus(status);
        
        
        // Enable IO for recording
        UInt32 flag = 1;
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Input,
                                      kInputBus,
                                      &flag,
                                      sizeof(flag));
        checkStatus(status);

        //开启回音消除
        UInt32 newEchoCancellationStatus = 0;
        checkStatus(AudioUnitSetProperty(audioUnit,
                                        kAUVoiceIOProperty_BypassVoiceProcessing,
                                        kAudioUnitScope_Global,
                                        0,
                                        &newEchoCancellationStatus,
                                        sizeof(newEchoCancellationStatus)));

        //kAudioUnitSubType_VoiceProcessingIO
        checkStatus(AudioUnitSetProperty(audioUnit,
                                         kAudioUnitSubType_VoiceProcessingIO,
                                         kAudioUnitScope_Global,
                                         0,
                                         &newEchoCancellationStatus,
                                         sizeof(newEchoCancellationStatus)));
        // Enable IO for playback
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Output,
                                      kOutputBus,
                                      &flag,
                                      sizeof(flag));
        checkStatus(status);
        
        // Describe format
        AudioStreamBasicDescription audioFormat;
        audioFormat.mSampleRate			= 8000;
        audioFormat.mFormatID			= kAudioFormatLinearPCM;
        audioFormat.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        audioFormat.mFramesPerPacket	= 1;
        audioFormat.mChannelsPerFrame	= 1;
        audioFormat.mBitsPerChannel		= 16;
        audioFormat.mBytesPerPacket		= 2;
        audioFormat.mBytesPerFrame		= 2;
        
        // Apply format
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Output,
                                      kInputBus,
                                      &audioFormat,
                                      sizeof(audioFormat));
        checkStatus(status);
        
        
        /* Make sure we set the correct audio category before restarting */
        UInt32 audioCategory = kAudioSessionCategory_PlayAndRecord;
        status = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,
                                         sizeof(audioCategory),
                                         &audioCategory);
        
        checkStatus(status);
        
        
        
        
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Input,
                                      kOutputBus,
                                      &audioFormat,
                                      sizeof(audioFormat));
        checkStatus(status);
        
        
        // Set input callback
        AURenderCallbackStruct callbackStruct;
        callbackStruct.inputProc = recordingCallback;
        callbackStruct.inputProcRefCon = (__bridge void *)(self);
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_SetInputCallback,
                                      kAudioUnitScope_Global,
                                      kInputBus,
                                      &callbackStruct,
                                      sizeof(callbackStruct));
        checkStatus(status);
        
        // Set output callback
        callbackStruct.inputProc = playbackCallback;
        callbackStruct.inputProcRefCon = (__bridge void *)(self);
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioUnitProperty_SetRenderCallback,
                                      kAudioUnitScope_Global,
                                      kOutputBus,
                                      &callbackStruct,
                                      sizeof(callbackStruct));
        checkStatus(status);
        
        // Disable buffer allocation for the recorder (optional - do this if we want to pass in our own)
        flag = 0;
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioUnitProperty_ShouldAllocateBuffer,
                                      kAudioUnitScope_Output,
                                      kInputBus,
                                      &flag,
                                      sizeof(flag));
        
        // Allocate our own buffers (1 channel, 16 bits per sample, thus 16 bits per frame, thus 2 bytes per frame).
        // Practice learns the buffers used contain 512 frames, if this changes it will be fixed in processAudio.
        tempBuffer.mNumberChannels = 1;
        
        tempBuffer.mDataByteSize = 1024 * 2;
        tempBuffer.mData = malloc( 1024 * 2 );
        
        isAudioUnitRunning = false;
        isBufferClean = false;
        

    }
    
    return self;
}


/**
 Start the audioUnit. This means data will be provided from
 the microphone, and requested for feeding to the speakers, by
 use of the provided callbacks.
 */
- (void) start: (AU_OPTYPE)opType audioFormat:(int)v_audioFormat{
    _audioFormat=v_audioFormat;
    if (isAudioUnitRunning) {
        if ((opType==AU_op_Listen&&m_opType==AU_op_Speak)||(opType==AU_op_Speak&&m_opType==AU_op_Listen)) {
            m_opType=3;
            AVAudioSession *audioSession = [AVAudioSession sharedInstance];
            [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
            return;
        }
    }
    m_opType=opType;
//    This will enable the proximity monitoring.允许临近检测
    
	OSStatus status;
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    //if(m_opType==AU_op_Listen)
    //    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    //else
    //    [audioSession setCategory:AVAudioSessionCategoryRecord error:nil];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];//触发2个回调函数recordingCallback、playbackCallback
    //设置为扬声器播放(AVAudioSessionCategoryPlayback才有效，AVAudioSessionCategoryPlayAndRecord时设置是无效的)
    //[[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    //使用kAudioSessionProperty_OverrideCategoryDefaultToSpeaker则除非你更改category，否则会一直生效
    UInt32 doChangeDefaultRoute = 1;
    AudioSessionSetProperty (
                             kAudioSessionProperty_OverrideCategoryDefaultToSpeaker,
                             sizeof (doChangeDefaultRoute),
                             &doChangeDefaultRoute
                             );
    [audioSession setActive:YES error:nil];
    
//    Activates the audio session
    status = AudioSessionSetActive(true);
    checkStatus(status);
    
//    Initialise the audio unit
	status = AudioUnitInitialize(audioUnit);
    checkStatus(status);

//    Starts the Audio Unit
    status = AudioOutputUnitStart(audioUnit);
	checkStatus(status);
    //有speak时才启动此线程发送音频
    if(m_opType==AU_op_Speak||m_opType==AU_op_ListenAndSpeak){
        if(![self isRecordDataPullingThreadRunning])
        {
            recorderThread = [[NSThread alloc] initWithTarget:self
                                                     selector:@selector(recordDataPullingMethod)//（麦克风采集到数据）不断将recordedPCMBuffer数据 encodeg729 decodeg729 再放到receivedPCMBuffer中(扬声器播放数据)
                                                       object:NULL];
            [self setIsRecordDataPullingThreadRunning:true];
            [recorderThread start];
    //        [recorderThread setThreadPriority:1.0];
        }
    }
    isAudioUnitRunning = true;
}

/**
 Stop the audioUnit
 */
- (void) stop : (AU_OPTYPE)opType{
    
    if (!isAudioUnitRunning) {
        return;
    }
    //单独关闭监听或者对讲
    if (m_opType!=opType&&opType!=AU_op_ListenAndSpeak) {
        m_opType=opType==AU_op_Speak?AU_op_Listen:AU_op_Listen;
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        if(m_opType==AU_op_Listen)
            [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        else
            [audioSession setCategory:AVAudioSessionCategoryRecord error:nil];
        return;
    }
    
//    This will disable the proximity monitoring.
    UIDevice *device = [UIDevice currentDevice];
    device.proximityMonitoringEnabled = NO;
    
    
    OSStatus status;
    
//    Stops the Audio Unit
	status = AudioOutputUnitStop(audioUnit);
	checkStatus(status);
    
//    Deactivates the audio session
    status = AudioSessionSetActive(false);
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    checkStatus(status);
    
//    Uninitialise the Audio Unit
	status = AudioUnitUninitialize(audioUnit);
    checkStatus(status);
    
    isRecordDataPullingThreadRunning = false;
    isAudioUnitRunning = false;
    
}

/**
 Change this funtion to decide what is done with incoming
 audio data from the microphone.
 Right now we copy it to our own temporary buffer.
 将麦克风采集的pcm音频数据放到recordedPCMBuffer队列中，等待在recordDataPullingMethod不断从此buffer队列中做这一系列动作（取数据、编码为g729,解码g729 放到receivedPCMBuffer队列中）
 */
- (void) processAudio: (AudioBufferList*) bufferList{
    
    bool isRecordedBufferProduceBytes = false;
    // @synchronized (self) {
//    GLog(tAudioSpeak,(@"recordedPCMBuffer3 count=%d",  recordedPCMBuffer.fillCount));
  //   }
    if (!isRecordedBufferProduceBytes) {
//        GLog(tAudioSpeak,(@"---------------------- Recorded RTP push faild ----------------------"));
    }
}

/*将recordedPCMBuffer队列的g729音频数据不断解码为pcm,然后放在receivedPCMBuffer队列中，等待在playbackCallback不断从此buffer队列中取数据播放  回放加速播放时没有声音数据*/
- (void) receiverAudio:(Byte *)audio WithLen:(int)len {
    memset(receivedShort, 0, 2048);

}


    dispatch_queue_t recordingqueue2;
        NSMutableData *fileData3;
/**
 This callback is called when new audio data from the microphone is
 available.
 */
static OSStatus recordingCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    AudioHandler *THIS = (__bridge AudioHandler *)(inRefCon);
    if(THIS->m_opType==AU_op_Speak||THIS->m_opType==AU_op_ListenAndSpeak){
        // Because of the way our audio format (setup below) is chosen:
        // we only need 1 buffer, since it is mono
        // Samples are 16 bits = 2 bytes.
        // 1 frame includes only 1 sample
        
        AudioBuffer buffer;
        buffer.mNumberChannels = 1;
        buffer.mDataByteSize = inNumberFrames * 2;
        buffer.mData = malloc( inNumberFrames * 2 );
        
        // Put buffer in a AudioBufferList
        AudioBufferList bufferList;
        bufferList.mNumberBuffers = 1;
        bufferList.mBuffers[0] = buffer;
        
        
        OSStatus status;
        status = AudioUnitRender([sharedInstance audioUnit],
                                 ioActionFlags,
                                 inTimeStamp,
                                 inBusNumber,
                                 inNumberFrames,
                                 &bufferList);
        checkStatus(status);
        
        // Now, we have the samples we just read sitting in buffers in bufferList
        // Process the new data
        [sharedInstance processAudio:&bufferList];
        
        return noErr;
    }
    return noErr;
}


/**
 This callback is called when the audioUnit needs new data to play through the
 speakers. If you don't have any, just don't write anything in the buffers
 */
static OSStatus playbackCallback(void *inRefCon,
								 AudioUnitRenderActionFlags *ioActionFlags,
								 const AudioTimeStamp *inTimeStamp,
								 UInt32 inBusNumber,
								 UInt32 inNumberFrames,
								 AudioBufferList *ioData) {
    // Notes: ioData contains buffers (may be more than one!)
    // Fill them up as much as you can. Remember to set the size value in each buffer to match how
    // much data is in the buffer.
    /*触发时机：当audioUnit需要用扬声器播放新数据时
     *流程：ioData是一个buffer数组，需要不断把音频数据填充的这个buff数组中，ios系统会自动播放完这个buffer数组后；再回调到此函数中,再把音频数据填充到这个buffer数组中，ios再自动播放，依次循环
     */
    AudioHandler *THIS = sharedInstance;

	for (int i=0; i < ioData->mNumberBuffers; i++) { // in practice we will only ever have 1 buffer, since audio format is mono

	}
    return noErr;
}

/**
 Clean up.
 */
- (void) dealloc {
	AudioUnitUninitialize(audioUnit);
	free(tempBuffer.mData);
}

@end
