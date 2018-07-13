//--------------------------------------------------------
// ORVXMMotor
// Created by Mark  A. Howe on Fri Jul 22 2005
// Code partially generated by the OrcaCodeWizard. Written by Mark A. Howe.
// Copyright (c) 2005 CENPA, University of Washington. All rights reserved.
//-----------------------------------------------------------
//This program was prepared for the Regents of the University of 
//Washington at the Center for Experimental Nuclear Physics and 
//Astrophysics (CENPA) sponsored in part by the United States 
//Department of Energy (DOE) under Grant #DE-FG02-97ER41020. 
//The University has certain rights in the program pursuant to 
//the contract and the program should not be copied or distributed 
//outside your organization.  The DOE and the University of 
//Washington reserve all rights in the program. Neither the authors,
//University of Washington, or U.S. Government make any warranty, 
//express or implied, or assume any liability or responsibility 
//for the use of this software.
//-------------------------------------------------------------

#pragma mark ***Imported Files
#import "ORVXMMotor.h"
#import "ORVXMModel.h"

#pragma mark ***External Strings
NSString* ORVXMMotorEnabledChanged		= @"ORVXMMotorEnabledChanged";
NSString* ORVXMMotorConversionChanged	= @"ORVXMMotorConversionChanged";
NSString* ORVXMMotorFullScaleChanged	= @"ORVXMMotorFullScaleChanged";
NSString* ORVXMMotorStateChanged		= @"ORVXMMotorStateChanged";
NSString* ORVXMMotorSpeedChanged		= @"ORVXMMotorSpeedChanged";
NSString* ORVXMMotorPositionChanged		= @"ORVXMMotorPositionChanged";
NSString* ORVXMMotorTargetChanged		= @"ORVXMMotorTargetChanged";
NSString* ORVXMMotorAbsMotionChanged	= @"ORVXMMotorAbsMotionChanged";
NSString* ORVXMMotorTypeChanged         = @"ORVXMMotorTypeChanged";


@implementation ORVXMMotor
- (id) initWithOwner:(id)anOwner motorNumber:(int)aMotorId //designated initializer
{	
    self = [super init];
    
    owner = anOwner;	//don't retain the guardian
    motorId = aMotorId;

    return self;
}
- (NSString*) description
{
    return [NSString stringWithFormat:@"id:%d  axis:%@  position:%d",motorId,axis,motorPosition];
}
- (int) motorId 
{
	return motorId;
}

- (void) setMotorId:(int)anId
{
	motorId = anId;
}

- (void) setOwner:(id)anObj
{
    owner = anObj;
}

- (id) owner
{
	return owner;
}

- (void) setMotorEnabled:(BOOL)aState
{
    [[[owner undoManager] prepareWithInvocationTarget:self] setMotorEnabled:motorEnabled];
    motorEnabled = aState;
	NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObject:self forKey:@"VMXMotor"];
    [[NSNotificationCenter defaultCenter] postNotificationName:ORVXMMotorEnabledChanged object:owner userInfo:userInfo];
}

- (BOOL) motorEnabled
{
	return motorEnabled;
}

- (float) conversion
{
	if(conversion==0)return 1;
    else return conversion;
}

- (void) setConversion:(float)aConversion
{
    [[[owner undoManager] prepareWithInvocationTarget:self] setConversion:conversion];
    
	if(aConversion == 0)aConversion = 1;
	
    conversion = aConversion;
	NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObject:self forKey:@"VMXMotor"];
    [[NSNotificationCenter defaultCenter] postNotificationName:ORVXMMotorConversionChanged object:owner userInfo:userInfo];
}

- (int) fullScale
{
    return fullScale;
}

- (void) setFullScale:(int)aFullScale
{
    [[[owner undoManager] prepareWithInvocationTarget:self] setFullScale:fullScale];
    
	if(aFullScale == 0)aFullScale = 100;
    fullScale = aFullScale;
	
	NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObject:self forKey:@"VMXMotor"];
    [[NSNotificationCenter defaultCenter] postNotificationName:ORVXMMotorFullScaleChanged object:owner userInfo:userInfo];
}

- (int) motorType
{
    return motorType;
}

- (void) setMotorType:(int)aType
{
    if(aType<0)aType = 0;
    else if(aType>6)aType = 6;
    [[[owner undoManager] prepareWithInvocationTarget:self] setMotorType:motorType];
    motorType = aType;
    
    sentMotorType = NO;
    
	NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObject:self forKey:@"VMXMotor"];
    [[NSNotificationCenter defaultCenter] postNotificationName:ORVXMMotorTypeChanged object:owner userInfo:userInfo];
}

- (void) setSentMotorType:(BOOL)aState
{
    sentMotorType = aState;
}

- (BOOL) sentMotorType
{
    return sentMotorType;
}

- (int) motorSpeed
{
    return motorSpeed;
}

- (void) setMotorSpeed:(int)aSpeed
{
    [[[owner undoManager] prepareWithInvocationTarget:self] setMotorSpeed:motorSpeed];
    
	if(aSpeed <= 0)aSpeed = 1;
	if(aSpeed >= 700)aSpeed = 700;
    motorSpeed = aSpeed;

	NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObject:self forKey:@"VMXMotor"];
    [[NSNotificationCenter defaultCenter] postNotificationName:ORVXMMotorSpeedChanged object:owner userInfo:userInfo];
}

- (BOOL) hasMoved
{
	if(oldMotorPosition != motorPosition){
		oldMotorPosition = motorPosition;
		return YES;
	}
	else return NO;
}

- (int) motorPosition
{
    return motorPosition;
}

- (void) setMotorPosition:(int)aPosition
{
	motorPosition = aPosition;
	NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObject:self forKey:@"VMXMotor"];
	[[NSNotificationCenter defaultCenter] postNotificationName:ORVXMMotorPositionChanged object:owner userInfo:userInfo];
}

- (int) targetPosition
{
    return targetPosition;
}

- (void) setTargetPosition:(int)aPosition
{
	[[[owner undoManager] prepareWithInvocationTarget:self] setTargetPosition:targetPosition];
	targetPosition = aPosition;
	NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObject:self forKey:@"VMXMotor"];
	[[NSNotificationCenter defaultCenter] postNotificationName:ORVXMMotorTargetChanged object:owner userInfo:userInfo];
}

- (BOOL) absoluteMotion
{
	return absoluteMotion;
}

- (NSString*) axis
{
    return axis;
}

- (void) setAxis:(NSString*)aString
{
    [axis autorelease];
    axis = [aString copy];
}

- (void) setAbsoluteMotion:(BOOL)aState
{
	[[[owner undoManager] prepareWithInvocationTarget:self] setAbsoluteMotion:absoluteMotion];
    absoluteMotion = aState;
	NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObject:self forKey:@"VMXMotor"];
    [[NSNotificationCenter defaultCenter] postNotificationName:ORVXMMotorAbsMotionChanged object:owner userInfo:userInfo];
}

#pragma mark ***Archival
- (id) initWithCoder:(NSCoder*)decoder
{
	self = [super init];
	[self setAbsoluteMotion:[decoder decodeBoolForKey: @"absoluteMotion"]];
	[self setMotorEnabled:	[decoder decodeBoolForKey: @"motorEnabled"]];	
	[self setConversion:	[decoder decodeFloatForKey:@"conversion"]];
	[self setFullScale:		[decoder decodeIntForKey:  @"fullScaleInt"]];
	[self setMotorSpeed:	[decoder decodeIntForKey:  @"motorSpeedInt"]];
	[self setTargetPosition:[decoder decodeIntForKey:  @"targetPosition"]];
	[self setMotorType:     [decoder decodeIntForKey:  @"motorType"]];
	return self;
}

- (void) encodeWithCoder:(NSCoder*)encoder
{
    [encoder encodeBool:	absoluteMotion	forKey:@"absoluteMotion"];	
    [encoder encodeBool:	motorEnabled	forKey:@"motorEnabled"];	
    [encoder encodeFloat:	conversion		forKey:@"conversion"];
    [encoder encodeInteger:		fullScale		forKey:@"fullScaleInt"];
    [encoder encodeInteger:		motorSpeed		forKey:@"motorSpeedInt"];
    [encoder encodeInteger:		targetPosition	forKey:@"targetPosition"];
    [encoder encodeInteger:		motorType       forKey:@"motorType"];
}

@end
