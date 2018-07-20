//
//  ESCAudioUnitPlayer.m
//  ESCAudioUnitDemo
//
//  Created by xiang on 2018/7/20.
//  Copyright © 2018年 xiang. All rights reserved.
//

#import "ESCAudioUnitPlayer.h"
#import <AVFoundation/AVFoundation.h>




@interface ESCAudioUnitPlayer () {
    AudioFileID audioFileId;
    AudioStreamBasicDescription streamBasicDescription;
    AudioUnit audioUnit;
}

@end

OSStatus aURenderCallback(    void *                            inRefCon,
                          AudioUnitRenderActionFlags *    ioActionFlags,
                          const AudioTimeStamp *            inTimeStamp,
                          UInt32                            inBusNumber,
                          UInt32                            inNumberFrames,
                          AudioBufferList * __nullable    ioData) {
    ESCAudioUnitPlayer *player = (__bridge ESCAudioUnitPlayer *)(inRefCon);
    
//    AudioUnitRender(player->audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData);
    
    return 0;
}

@implementation ESCAudioUnitPlayer

- (instancetype)initWithFilePath:(NSString *)filePath {
    if (self = [super init]) {
        
        CFStringRef cfFilePath = (__bridge CFStringRef)filePath;
        //创建url
        CFURLRef cfURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,cfFilePath , kCFURLPOSIXPathStyle, false);
        //打开文件
        int error = AudioFileOpenURL(cfURL, kAudioFileReadPermission, 0, &audioFileId);
        if ([self checkError:error] == NO) {
            return nil;
        }else {
            NSLog(@"打开文件成功");
        }
        //释放url
        CFRelease(cfURL);
        //计算结构体数据大小
        UInt32 dateFormatSize = sizeof(streamBasicDescription);
        NSLog(@"dateFormatSize == %u",(unsigned int)dateFormatSize);
        //获取格式
        error = AudioFileGetProperty(audioFileId, kAudioFilePropertyDataFormat, &dateFormatSize, &streamBasicDescription);
        if ([self checkError:error] == NO) {
            NSLog(@"格式获取失败");
            return nil;
        }else {
            NSLog(@"格式获取成功");
        }
        //得到最大包的大小
        UInt32 maxPacketSize;
        UInt32 propertySize = sizeof(maxPacketSize);
        error = AudioFileGetProperty(audioFileId, kAudioFilePropertyPacketSizeUpperBound, &propertySize, &maxPacketSize);
        if ([self checkError:error] == NO) {
            NSLog(@"取最大包大小失败");
            return nil;
        }else {
            NSLog(@"最大包大小为：%u",(unsigned int)maxPacketSize);
        }
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
            
            AUGraphNodeInfo(processingGraph, ioNode, NULL, &audioUnit);
            
            OSStatus status = noErr;
            UInt32 oneFlag = 1;
            UInt32 busZero = 0;
            //连接硬件
            status = AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, busZero, &oneFlag, sizeof(oneFlag));
            if (status != 0) {
                NSLog(@"Could not connect to speaker");
            }
            
            //            //启动麦克风
            //            UInt32 busOne = 1;
            //            AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, busOne, &oneFlag, sizeof(oneFlag));
            //
            //            UInt32 bytesPerSample = sizeof(Float32);
            //            AudioStreamBasicDescription asbd;
            
            //设置属性
            AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &streamBasicDescription, sizeof(streamBasicDescription));
            
            //设置回调
            AURenderCallbackStruct callbackStruct;
            callbackStruct.inputProc = aURenderCallback;
            callbackStruct.inputProcRefCon = (__bridge void *)(self);
            status = AudioUnitSetProperty(audioUnit,
                                          kAudioUnitProperty_SetRenderCallback,
                                          kAudioUnitScope_Global,
                                          busZero,
                                          &callbackStruct,
                                          sizeof(callbackStruct));
            if (status != 0) {
                [self checkError:status];
                return nil;
            }
        }
        //
    }
    return self;
}

- (void)startPlay {
    AudioUnitInitialize(audioUnit);
    AudioOutputUnitStart(audioUnit);
}

- (void)stop {
    AudioOutputUnitStop(audioUnit);
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
