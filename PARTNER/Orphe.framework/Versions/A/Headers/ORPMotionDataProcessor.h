//
//  ORPMotionDataProcessor.h
//
//
//  Created by no new folk studio Inc. on 2016/10/18.
//  Copyright © 2016 no new folk studio Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ORPGestureEventArgs.h"

typedef NS_ENUM(int,ORPSide) {
 ORPSide_Left = 0,
 ORPSide_Right = 1
};

typedef NS_ENUM(UInt8,ORPGestureSensitivity) {
    ORPGestureSensitivity_Low,
    ORPGestureSensitivity_Mid,
    ORPGestureSensitivity_High
};

typedef NS_ENUM(int,ORPAccRange) {
    ORPAccRange_2 = 2,
    ORPAccRange_4 = 4,
    ORPAccRange_8 = 8,
    ORPAccRange_16 = 16,
};

typedef NS_ENUM(int,ORPGyroRange) {
    ORPGyroRange_250 = 250,
    ORPGyroRange_500 = 500,
    ORPGyroRange_1000 = 1000,
    ORPGyroRange_2000 = 2000,
};

int ORPAngleRange = 180;

@interface ORPMotionDataProcessor : NSObject

@property NSMutableArray* accArray;
@property NSMutableArray* gyroArray;
@property NSMutableArray* eulerArray;
@property NSMutableArray* quatArray;
@property NSMutableArray* magArray;
@property NSMutableArray* gravityArray;
@property NSMutableArray* normalizedAccArray;
@property NSMutableArray* normalizedGyroArray;
@property NSMutableArray* normalizedEulerArray;
@property NSMutableArray* normalizedMagArray;
@property ORPAccRange accRange;
@property ORPGyroRange gyroRange;
@property ORPGestureEventArgs* gestureEventArgs;
@property uint8_t fwVersion;

- (instancetype)initWithSide:(int)side;

- (void) updateSensorData:(NSData*)data;

- (void)setSide:(ORPSide)side;

- (uint8_t)getShock;

- (float)getAccLength;
- (float)getMovementPower;

- (float)getPowerWithFrameNum:(int)frameNum ;

- (void) setGestureSensitivity:(ORPGestureSensitivity)sensitivity;

- (float) getGestureSensitivity;

- (void) resetAttitude;

- (void)setSensorValues:(NSArray*)q :(NSArray*)e :(NSArray*)a :(NSArray*)g :(uint16_t)m :(uint8_t)shock;

@end
