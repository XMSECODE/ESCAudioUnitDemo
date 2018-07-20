//
//  ESCAudioUnitPlayer.h
//  ESCAudioUnitDemo
//
//  Created by xiang on 2018/7/20.
//  Copyright © 2018年 xiang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ESCAudioUnitPlayer : NSObject

- (instancetype)initWithFilePath:(NSString *)filePath;

- (void)startPlay;

- (void)stop;

- (void)pause;

@end
