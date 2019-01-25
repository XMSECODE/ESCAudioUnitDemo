//
//  ESCAudioUnitPlayer.m
//  ESCAudioUnitDemo
//
//  Created by xiang on 2018/7/20.
//  Copyright © 2018年 xiang. All rights reserved.
//

#import "ESCAudioUnitPlayer.h"
#import <AVFoundation/AVFoundation.h>


typedef struct AQPlayerState {
    AudioStreamBasicDescription   mDataFormat;
    AudioQueueRef                 mQueue;
    AudioQueueBufferRef           mBuffers[3];
    AudioFileID                   mAudioFile;
    UInt32                        bufferByteSize;
    SInt64                        mCurrentPacket;
    UInt32                        mNumPacketsToRead;
    AudioStreamPacketDescription  *mPacketDescs;
    bool                          mIsRunning;
    AudioUnit                       audioUnit;

}AQPlayerState;


@interface ESCAudioUnitPlayer ()

@property(nonatomic,assign)AQPlayerState playerState;

@end

void DeriveBufferSize (AudioStreamBasicDescription inDesc,UInt32 maxPacketSize,Float64 inSeconds,UInt32 *outBufferSize,UInt32 *outNumPacketsToRead) {
    
    static const int maxBufferSize = 0x10000;
    static const int minBufferSize = 0x4000;
    
    if (inDesc.mFramesPerPacket != 0) {
        //如果每个Packet不止一个Frame，则按照包进行计算
        Float64 numPacketsForTime = inDesc.mSampleRate / inDesc.mFramesPerPacket * inSeconds;
        *outBufferSize = numPacketsForTime * maxPacketSize;
    } else {
        //如果每个Packet只有一个Frame，则直接确定缓冲区大小
        *outBufferSize = maxBufferSize > maxPacketSize ? maxBufferSize : maxPacketSize;
    }
    
    if (*outBufferSize > maxBufferSize && *outBufferSize > maxPacketSize){
        *outBufferSize = maxBufferSize;
    }
    else {
        if (*outBufferSize < minBufferSize){
            *outBufferSize = minBufferSize;
        }
    }
    
    *outNumPacketsToRead = *outBufferSize / maxPacketSize;
}

OSStatus aURenderCallback(    void *                            inRefCon,
                          AudioUnitRenderActionFlags *    ioActionFlags,
                          const AudioTimeStamp *            inTimeStamp,
                          UInt32                            inBusNumber,
                          UInt32                            inNumberFrames,
                          AudioBufferList * __nullable    ioData) {
    NSLog(@"aURenderCallback");
    
    AQPlayerState *pAqData = (AQPlayerState *) inRefCon;
//    AudioFileReadPacketData(pAqData->mAudioFile, false, &numBytesReadFromFile, pAqData->mPacketDescs, pAqData->mCurrentPacket, &numPackets, inBuffer->mAudioData);
    /*
     extern OSStatus
     AudioFileReadPacketData (    AudioFileID                      inAudioFile,
     Boolean                            inUseCache,
     UInt32 *                        ioNumBytes,
     AudioStreamPacketDescription * __nullable outPacketDescriptions,
     SInt64                            inStartingPacket,
     UInt32 *                         ioNumPackets,
     void * __nullable                outBuffer)            API_AVAILABLE(macos(10.6), ios(2.2), watchos(2.0), tvos(9.0));
     */
    UInt32 numBytesReadFromFile = 4096;
    UInt32 numPackets = pAqData->mNumPacketsToRead;

    void *buffer = malloc(1024 * 100);
    
    OSStatus status = AudioFileReadPacketData(pAqData->mAudioFile, false, &numBytesReadFromFile, pAqData->mPacketDescs, pAqData->mCurrentPacket, &numPackets, buffer);

    if (status != noErr) {
        NSLog(@"读取数据失败");
        return -1;
    }else {
        NSLog(@"%d===%ld",numPackets,pAqData->mCurrentPacket);
    }
    
    if (numPackets > 0) {
        pAqData->mCurrentPacket += numPackets;

        printf("numPackets > 0  播放==%u\n",(unsigned int)numBytesReadFromFile);
        ioData->mBuffers[0].mDataByteSize = numBytesReadFromFile;
//        inBuffer->mAudioDataByteSize = numBytesReadFromFile;
        memcpy(ioData->mBuffers[0].mData, buffer, numBytesReadFromFile);
        status = AudioUnitRender(pAqData->audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData);
        if (status != noErr) {
            NSLog(@"填充数据失败==%d",status);
            return status;
        }
//        AudioQueueEnqueueBuffer(inAQ,inBuffer,(pAqData->mPacketDescs ? numPackets : 0),pAqData->mPacketDescs);
    } else {
        
    }
    free(buffer);
    /*
     AudioUnitRender(                    AudioUnit                        inUnit,
     AudioUnitRenderActionFlags * __nullable ioActionFlags,
     const AudioTimeStamp *            inTimeStamp,
     UInt32                            inOutputBusNumber,
     UInt32                            inNumberFrames,
     AudioBufferList *                ioData)
     API_AVAILABLE(macos(10.2), ios(2.0), watchos(2.0), tvos(9.0));
     */
   
    return 0;
}

@implementation ESCAudioUnitPlayer
static int play_element = 0;

- (instancetype)initWithFilePath:(NSString *)filePath {
    if (self = [super init]) {
        
        CFStringRef cfFilePath = (__bridge CFStringRef)filePath;
        //创建url
        CFURLRef cfURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,cfFilePath , kCFURLPOSIXPathStyle, false);
        //打开文件
        int error = AudioFileOpenURL(cfURL, kAudioFileReadPermission, 0, &_playerState.mAudioFile);
        if ([self checkError:error] == NO) {
            return nil;
        }else {
            NSLog(@"打开文件成功");
        }
        //释放url
        CFRelease(cfURL);
        //计算结构体数据大小
        UInt32 dateFormatSize = sizeof(_playerState.mDataFormat);
        NSLog(@"dateFormatSize == %u",(unsigned int)dateFormatSize);
        //获取格式
        error = AudioFileGetProperty(_playerState.mAudioFile, kAudioFilePropertyDataFormat, &dateFormatSize, &_playerState.mDataFormat);
        if ([self checkError:error] == NO) {
            NSLog(@"格式获取失败");
            return nil;
        }else {
            NSLog(@"格式获取成功");
        }
        //得到最大包的大小
        UInt32 maxPacketSize;
        UInt32 propertySize = sizeof(maxPacketSize);
        error = AudioFileGetProperty(_playerState.mAudioFile, kAudioFilePropertyPacketSizeUpperBound, &propertySize, &maxPacketSize);
        if ([self checkError:error] == NO) {
            NSLog(@"取最大包大小失败");
            return nil;
        }else {
            NSLog(@"最大包大小为：%u",(unsigned int)maxPacketSize);
        }
        //计算buffer size大小
        DeriveBufferSize(_playerState.mDataFormat, maxPacketSize, 0.5, &_playerState.bufferByteSize, &_playerState.mNumPacketsToRead);
        
        bool isFormatVBR = (_playerState.mDataFormat.mBytesPerPacket == 0 ||_playerState.mDataFormat.mFramesPerPacket == 0);
        
        if (isFormatVBR) {
            _playerState.mPacketDescs =(AudioStreamPacketDescription*) malloc (_playerState.mNumPacketsToRead * sizeof (AudioStreamPacketDescription));
        } else {
            _playerState.mPacketDescs = NULL;
        }
        
        
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
        
        AUGraphNodeInfo(processingGraph, ioNode, NULL, &_playerState.audioUnit);
        
        OSStatus status = noErr;
        UInt32 oneFlag = 1;
        UInt32 busZero = 0;
        //连接硬件
        status = AudioUnitSetProperty(_playerState.audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, busZero, &oneFlag, sizeof(oneFlag));
        if (status != 0) {
            NSLog(@"Could not connect to drawdevice");
            return nil;
        }
       
        //设置属性-》不能直接播放MP3文件，需要进行格式转换
        status = AudioUnitSetProperty(_playerState.audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, busZero, &_playerState.mDataFormat, sizeof(_playerState.mDataFormat));
        if (status != noErr) {
            NSLog(@"AudioUnitSetProperty failed!");
            [self checkError:status];
            return nil;
        }
        
        //设置回调
        AURenderCallbackStruct callbackStruct;
        callbackStruct.inputProc = aURenderCallback;
        callbackStruct.inputProcRefCon = &_playerState;
        status = AudioUnitSetProperty(_playerState.audioUnit,
                                      kAudioUnitProperty_SetRenderCallback,
                                      kAudioUnitScope_Global,
                                      busZero,
                                      &callbackStruct,
                                      sizeof(callbackStruct));
        if (status != 0) {
            [self checkError:status];
            return nil;
        }
        //
    }
    return self;
}

- (void)startPlay {
    OSStatus status = AudioUnitInitialize(_playerState.audioUnit);
    if (status != noErr) {
        [self checkError:status];
        return;
    }
    status = AudioOutputUnitStart(_playerState.audioUnit);
}

- (void)stop {
    AudioOutputUnitStop(_playerState.audioUnit);
}

- (void)pause {
    
}
- (BOOL)checkError:(int)error {
    if (error == noErr) {
        return YES;
    }
    if (error == kAudioFileUnspecifiedError) {
        NSLog(@"kAudioFileUnspecifiedError");
    } else if(error == kAudioFileUnsupportedFileTypeError){
        NSLog(@"kAudioFileUnsupportedFileTypeError");
    }else if(error == kAudioFileUnsupportedDataFormatError){
        NSLog(@"kAudioFileUnsupportedDataFormatError");
    }else if(error == kAudioFileUnsupportedPropertyError){
        NSLog(@"kAudioFileUnsupportedPropertyError");
    }else if(error == kAudioFileBadPropertySizeError){
        NSLog(@"kAudioFileBadPropertySizeError");
    }else if(error == kAudioFilePermissionsError){
        NSLog(@"kAudioFilePermissionsError");
    }else if(error == kAudioFileNotOptimizedError){
        NSLog(@"kAudioFileNotOptimizedError");
    }else if(error == kAudioFileInvalidChunkError){
        NSLog(@"kAudioFileInvalidChunkError");
    }else if(error == kAudioFileDoesNotAllow64BitDataSizeError){
        NSLog(@"kAudioFileDoesNotAllow64BitDataSizeError");
    }else if(error == kAudioFileInvalidPacketOffsetError){
        NSLog(@"kAudioFileInvalidPacketOffsetError");
    }else if(error == kAudioFileInvalidFileError){
        NSLog(@"kAudioFileInvalidFileError");
    }else if(error == kAudioFileOperationNotSupportedError){
        NSLog(@"kAudioFileOperationNotSupportedError");
    }else if(error == kAudioFileNotOpenError){
        NSLog(@"kAudioFileNotOpenError");
    }else if(error == kAudioFileEndOfFileError){
        NSLog(@"kAudioFileEndOfFileError");
    }else if(error == kAudioFilePositionError){
        NSLog(@"kAudioFilePositionError");
    }else if(error == kAudioFileFileNotFoundError){
        NSLog(@"kAudioFileFileNotFoundError");
    }
    
    return NO;
}
@end
