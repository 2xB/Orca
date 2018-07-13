//--------------------------------------------------------
// ORBocTIC3Model
// Created by Mark  A. Howe on Mon Aug 27 2007
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

#pragma mark ���Imported Files

#import "ORBocTIC3Model.h"
#import "ORSerialPort.h"
#import "ORSerialPortList.h"
#import "ORSerialPort.h"
#import "ORSerialPortAdditions.h"
#import "ORDataTypeAssigner.h"
#import "ORDataPacket.h"
#import "ORTimeRate.h"

#pragma mark ���External Strings
NSString* ORBocTIC3ModelPressureScaleChanged = @"ORBocTIC3ModelPressureScaleChanged";
NSString* ORBocTIC3ModelShipPressuresChanged	= @"ORBocTIC3ModelShipPressuresChanged";
NSString* ORBocTIC3ModelPollTimeChanged			= @"ORBocTIC3ModelPollTimeChanged";
NSString* ORBocTIC3ModelSerialPortChanged		= @"ORBocTIC3ModelSerialPortChanged";
NSString* ORBocTIC3ModelPortNameChanged			= @"ORBocTIC3ModelPortNameChanged";
NSString* ORBocTIC3ModelPortStateChanged		= @"ORBocTIC3ModelPortStateChanged";
NSString* ORBocTIC3PressureChanged				= @"ORBocTIC3PressureChanged";

NSString* ORBocTIC3Lock = @"ORBocTIC3Lock";

@interface ORBocTIC3Model (private)
- (void) runStarted:(NSNotification*)aNote;
- (void) runStopped:(NSNotification*)aNote;
- (void) timeout;
- (void) processOneCommandFromQueue;
- (void) process_response:(NSString*)theResponse;
- (void) pollPressures;
@end

@implementation ORBocTIC3Model
- (id) init
{
	self = [super init];
    [self registerNotificationObservers];
	return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [buffer release];
	[cmdQueue release];
	[lastRequest release];
    [portName release];
    if([serialPort isOpen]){
        [serialPort close];
    }
    [serialPort release];
	int i;
	for(i=0;i<3;i++){
		[timeRates[i] release];
	}

	[super dealloc];
}

- (void) setUpImage
{
	[self setImage:[NSImage imageNamed:@"BocTIC3.tif"]];
}

- (void) makeMainController
{
	[self linkToController:@"ORBocTIC3Controller"];
}

- (NSString*) helpURL
{
	return @"RS232/BocTIC3.html";
}

- (void) registerNotificationObservers
{
	NSNotificationCenter* notifyCenter = [NSNotificationCenter defaultCenter];

    [notifyCenter addObserver : self
                     selector : @selector(dataReceived:)
                         name : ORSerialPortDataReceived
                       object : nil];

    [notifyCenter addObserver: self
                     selector: @selector(runStarted:)
                         name: ORRunStartedNotification
                       object: nil];
    
    [notifyCenter addObserver: self
                     selector: @selector(runStopped:)
                         name: ORRunStoppedNotification
                       object: nil];

}

- (void) dataReceived:(NSNotification*)note
{
    if([[note userInfo] objectForKey:@"serialPort"] == serialPort){
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeout) object:nil];
        NSString* theString = [[[[NSString alloc] initWithData:[[note userInfo] objectForKey:@"data"] 
												      encoding:NSASCIIStringEncoding] autorelease] uppercaseString];

		//the serial port may break the data up into small chunks, so we have to accumulate the chunks until
		//we get a full piece.
        theString = [[theString componentsSeparatedByString:@"\n"] componentsJoinedByString:@""];
        if(!buffer)buffer = [[NSMutableString string] retain];
        [buffer appendString:theString];					
		
        do {
            NSRange lineRange = [buffer rangeOfString:@"\r"];
            if(lineRange.location!= NSNotFound){
                NSMutableString* theResponse = [[[buffer substringToIndex:lineRange.location+1] mutableCopy] autorelease];
                [buffer deleteCharactersInRange:NSMakeRange(0,lineRange.location+1)];      //take the cmd out of the buffer
				
				[self process_response:theResponse];
		
				[self setLastRequest:nil];			 //clear the last request
				[self processOneCommandFromQueue];	 //do the next command in the queue
            }
        } while([buffer rangeOfString:@"\r"].location!= NSNotFound);
	}
}


- (void) shipPressureValues
{
    if([[ORGlobal sharedGlobal] runInProgress]){
		
		unsigned long data[8];
		data[0] = dataId | 8;
		data[1] = [self uniqueIdNumber]&0xfff;
		
		union {
			float asFloat;
			unsigned long asLong;
		}theData;
		int index = 2;
		int i;
		for(i=0;i<3;i++){
			theData.asFloat = pressure[i];
			data[index] = theData.asLong;
			index++;
			
			data[index] = timeMeasured[i];
			index++;
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:ORQueueRecordForShippingNotification 
															object:[NSData dataWithBytes:data length:sizeof(long)*8]];
	}
}


#pragma mark ���Accessors
- (float) pressureScaleValue
{
	return pressureScaleValue;
}

- (int) pressureScale
{
    return pressureScale;
}

- (void) setPressureScale:(int)aPressureScale
{
	if(aPressureScale<0)aPressureScale=0;
	else if(aPressureScale>11)aPressureScale=11;
	
    [[[self undoManager] prepareWithInvocationTarget:self] setPressureScale:pressureScale];
    
    pressureScale = aPressureScale;
	
	pressureScaleValue = powf(10.,(float)pressureScale);

    [[NSNotificationCenter defaultCenter] postNotificationName:ORBocTIC3ModelPressureScaleChanged object:self];
}

- (ORTimeRate*)timeRate:(int)index
{
	return timeRates[index];
}

- (BOOL) shipPressures
{
    return shipPressures;
}

- (void) setShipPressures:(BOOL)aShipPressures
{
    [[[self undoManager] prepareWithInvocationTarget:self] setShipPressures:shipPressures];
    
    shipPressures = aShipPressures;

    [[NSNotificationCenter defaultCenter] postNotificationName:ORBocTIC3ModelShipPressuresChanged object:self];
}

- (int) pollTime
{
    return pollTime;
}

- (void) setPollTime:(int)aPollTime
{
    [[[self undoManager] prepareWithInvocationTarget:self] setPollTime:pollTime];
    pollTime = aPollTime;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBocTIC3ModelPollTimeChanged object:self];

	if(pollTime){
		[self performSelector:@selector(pollPressures) withObject:nil afterDelay:2];
	}
	else {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pollPressures) object:nil];
	}
}


- (float) pressure:(int)index
{
	if(index>=0 && index<3)return pressure[index];
	else return 0.0;
}

- (unsigned long) timeMeasured:(int)index
{
	if(index>=0 && index<3)return timeMeasured[index];
	else return 0;
}

- (void) setPressure:(int)index value:(float)aValue;
{
	if(index>=0 && index<3){
		pressure[index] = aValue;
		//get the time(UT!)
		time_t	ut_Time;
		time(&ut_Time);
		//struct tm* theTimeGMTAsStruct = gmtime(&theTime);
		timeMeasured[index] = ut_Time;

		[[NSNotificationCenter defaultCenter] postNotificationName:ORBocTIC3PressureChanged 
															object:self 
														userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:index] forKey:@"Index"]];

		if(timeRates[index] == nil) timeRates[index] = [[ORTimeRate alloc] init];
		[timeRates[index] addDataToTimeAverage:aValue];

	}
}

- (NSString*) lastRequest
{
	return lastRequest;
}

- (void) setLastRequest:(NSString*)aRequest
{
	[lastRequest autorelease];
	lastRequest = [aRequest copy];    
}

- (BOOL) portWasOpen
{
    return portWasOpen;
}

- (void) setPortWasOpen:(BOOL)aPortWasOpen
{
    portWasOpen = aPortWasOpen;
}

- (NSString*) portName
{
    return portName;
}

- (void) setPortName:(NSString*)aPortName
{
    [[[self undoManager] prepareWithInvocationTarget:self] setPortName:portName];
    
    if(![aPortName isEqualToString:portName]){
        [portName autorelease];
        portName = [aPortName copy];    

        BOOL valid = NO;
        NSEnumerator *enumerator = [ORSerialPortList portEnumerator];
        ORSerialPort *aPort;
        while (aPort = [enumerator nextObject]) {
            if([portName isEqualToString:[aPort name]]){
                [self setSerialPort:aPort];
                if(portWasOpen){
                    [self openPort:YES];
                 }
                valid = YES;
                break;
            }
        } 
        if(!valid){
            [self setSerialPort:nil];
        }       
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:ORBocTIC3ModelPortNameChanged object:self];
}

- (ORSerialPort*) serialPort
{
    return serialPort;
}

- (void) setSerialPort:(ORSerialPort*)aSerialPort
{
    [aSerialPort retain];
    [serialPort release];
    serialPort = aSerialPort;

    [[NSNotificationCenter defaultCenter] postNotificationName:ORBocTIC3ModelSerialPortChanged object:self];
}

- (void) openPort:(BOOL)state
{
    if(state) {
        [serialPort open];
		[serialPort setSpeed:9600];
		[serialPort setParityOdd];
		[serialPort setStopBits2:1];
		[serialPort setDataBits:7];
		[serialPort commitChanges];
    }
    else      [serialPort close];
    portWasOpen = [serialPort isOpen];
    [[NSNotificationCenter defaultCenter] postNotificationName:ORBocTIC3ModelPortStateChanged object:self];
    
}


#pragma mark ���Archival
- (id) initWithCoder:(NSCoder*)decoder
{
	self = [super initWithCoder:decoder];
	[[self undoManager] disableUndoRegistration];
	[self setPressureScale:[decoder decodeIntForKey:@"ORBocTIC3ModelPressureScale"]];
	[self setShipPressures:[decoder decodeBoolForKey:@"ORBocTIC3ModelShipPressures"]];
	[self setPollTime:[decoder decodeIntForKey:@"ORBocTIC3ModelPollTime"]];
	[self setPortWasOpen:[decoder decodeBoolForKey:@"ORBocTIC3ModelPortWasOpen"]];
    [self setPortName:[decoder decodeObjectForKey: @"portName"]];
	[[self undoManager] enableUndoRegistration];
	int i;
	for(i=0;i<3;i++){
		timeRates[i] = [[ORTimeRate alloc] init];
	}
    [self registerNotificationObservers];

	return self;
}
- (void) encodeWithCoder:(NSCoder*)encoder
{
    [super encodeWithCoder:encoder];
    [encoder encodeInteger:pressureScale forKey:@"ORBocTIC3ModelPressureScale"];
    [encoder encodeBool:shipPressures forKey:@"ORBocTIC3ModelShipPressures"];
    [encoder encodeInteger:pollTime forKey:@"ORBocTIC3ModelPollTime"];
    [encoder encodeBool:portWasOpen forKey:@"ORBocTIC3ModelPortWasOpen"];
    [encoder encodeObject:portName forKey: @"portName"];
}

#pragma mark ��� Commands
- (void) addCmdToQueue:(NSString*)aCmd
{
    if([serialPort isOpen]){ 
		if(!cmdQueue)cmdQueue = [[NSMutableArray array] retain];
		[cmdQueue addObject:aCmd];
		if(!lastRequest){
			[self processOneCommandFromQueue];
		}
	}
}

- (void) readPressures
{
	[self addCmdToQueue:@"?V913"];
	[self addCmdToQueue:@"?V914"];
	[self addCmdToQueue:@"?V915"];
	[self addCmdToQueue:@"++ShipRecords"];
}

#pragma mark ���Data Records
- (unsigned long) dataId { return dataId; }
- (void) setDataId: (unsigned long) DataId
{
    dataId = DataId;
}
- (void) setDataIds:(id)assigner
{
    dataId       = [assigner assignDataIds:kLongForm];
}

- (void) syncDataIdsWith:(id)anotherBocTIC3
{
    [self setDataId:[anotherBocTIC3 dataId]];
}

- (void) appendDataDescription:(ORDataPacket*)aDataPacket userInfo:(NSDictionary*)userInfo
{
    //----------------------------------------------------------------------------------------
    // first add our description to the data description
    [aDataPacket addDataDescriptionItem:[self dataRecordDescription] forKey:@"BocTIC3Model"];
}

- (NSDictionary*) dataRecordDescription
{
    NSMutableDictionary* dataDictionary = [NSMutableDictionary dictionary];
    NSDictionary* aDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        @"ORBocTIC3DecoderForPressure",     @"decoder",
        [NSNumber numberWithLong:dataId],   @"dataId",
        [NSNumber numberWithBool:NO],       @"variable",
        [NSNumber numberWithLong:8],        @"length",
        nil];
    [dataDictionary setObject:aDictionary forKey:@"Pressures"];
    
    return dataDictionary;
}

@end

@implementation ORBocTIC3Model (private)
- (void) runStarted:(NSNotification*)aNote
{
}

- (void) runStopped:(NSNotification*)aNote
{
}

- (void) timeout
{
	NSLogError(@"command timeout",@"BOC TIC 3",nil);
	[self setLastRequest:nil];
	[self processOneCommandFromQueue];	 //do the next command in the queue
}

- (void) processOneCommandFromQueue
{
	if([cmdQueue count] == 0) return;
	NSString* aCmd = [[[cmdQueue objectAtIndex:0] retain] autorelease];
	[cmdQueue removeObjectAtIndex:0];
	if([aCmd isEqualToString:@"++ShipRecords"]){
		if(shipPressures) [self shipPressureValues];
	}
	else {
		if([aCmd rangeOfString:@"?"].location != NSNotFound){
			[self setLastRequest:aCmd];
			[self performSelector:@selector(timeout) withObject:nil afterDelay:3];
		}
		if(![aCmd hasSuffix:@"\r"]) aCmd = [aCmd stringByAppendingString:@"\r"];
		[serialPort writeString:aCmd];
		if(!lastRequest){
			[self performSelector:@selector(processOneCommandFromQueue) withObject:nil afterDelay:.01];
		}
	}
}

- (void) process_response:(NSString*)theResponse
{
	if([theResponse hasPrefix:@"=V"]){
	
		//----------------------------------
		//format =V914 1.74e-02;59;11;0;0
		// value;units type;state;alertID;priority
		//----------------------------------
		NSArray* mainParts = [theResponse componentsSeparatedByString:@" "];
		if([mainParts count]>=2){
			int gaugeNumber = [[[mainParts objectAtIndex:0] substringFromIndex:2] intValue] - kStartingBocGaugeNumber;
			if(gaugeNumber>=0 && gaugeNumber<3){
				NSArray* subParts = [[mainParts objectAtIndex:1] componentsSeparatedByString:@";"];
				[self setPressure:gaugeNumber value:[[subParts objectAtIndex:0] floatValue]];
			}
		}
	}
}
- (void) pollPressures
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pollPressures) object:nil];
	[self readPressures];
	
	[self performSelector:@selector(pollPressures) withObject:nil afterDelay:pollTime];
}

@end
