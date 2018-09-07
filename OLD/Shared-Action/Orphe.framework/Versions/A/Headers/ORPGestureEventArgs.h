//
//  ORPGestureEventArgs.h
//
//
//  Created by no new folk studio Inc. on 2016/10/18.
//  Copyright © 2016 no new folk studio Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, ORPGestureKind) {
    ORPGestureKind_NOTHING,
    ORPGestureKind_STEP_TOE,
    ORPGestureKind_STEP_FLAT,
    ORPGestureKind_STEP_HEEL,
    ORPGestureKind_KICK,
};

@interface ORPGestureEventArgs : NSObject

- (void) setGestureEventArgs:(ORPGestureKind)_gesture Power:(float)_power;
-(ORPGestureKind)getGestureKind;
-(NSString*) getGestureKindString;
-(float) getPower;

@end
