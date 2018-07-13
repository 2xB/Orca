//--------------------------------------------------------
// ORTPG262Model
// Code partially generated by the OrcaCodeWizard. Written by Mark A. Howe.
//  Created by Mark Howe on Mon Feb 28 2011.
//  Copyright 2011  University of North Carolina. All rights reserved.
//-----------------------------------------------------------
//This program was prepared for the Regents of the University of 
//North Carolina at the Center for Experimental Nuclear Physics and 
//Astrophysics (CENPA) sponsored in part by the United States 
//Department of Energy (DOE) under Grant #DE-FG02-97ER41020. 
//The University has certain rights in the program pursuant to 
//the contract and the program should not be copied or distributed 
//outside your organization.  The DOE and the University of 
//North Carolina reserve all rights in the program. Neither the authors,
//University of North Carolina, or U.S. Government make any warranty, 
//express or implied, or assume any liability or responsibility 
//for the use of this software.
//-------------------------------------------------------------

#pragma mark •••Imported Files

#import "ORTPG262Model.h"
#import "ORSerialPort.h"
#import "ORSerialPortList.h"
#import "ORSerialPort.h"
#import "ORSerialPortAdditions.h"
#import "ORDataTypeAssigner.h"
#import "ORDataPacket.h"
#import "ORTimeRate.h"
#import "ORSafeQueue.h"

#pragma mark •••External Strings
NSString* ORTPG262ModelPressureScaleChanged = @"ORTPG262ModelPressureScaleChanged";
NSString* ORTPG262ModelShipPressuresChanged	= @"ORTPG262ModelShipPressuresChanged";
NSString* ORTPG262ModelPollTimeChanged		= @"ORTPG262ModelPollTimeChanged";
NSString* ORTPG262ModelSerialPortChanged	= @"ORTPG262ModelSerialPortChanged";
NSString* ORTPG262ModelPortNameChanged		= @"ORTPG262ModelPortNameChanged";
NSString* ORTPG262ModelPortStateChanged		= @"ORTPG262ModelPortStateChanged";
NSString* ORTPG262PressureChanged			= @"ORTPG262PressureChanged";

NSString* ORTPG262Lock = @"ORTPG262Lock";

#define kACK			0x06
#define kNAK			0x15
#define kENQ			0x05
#define kEXT			0x03
#define kWaitingForACK	1
#define kProcessData	2


@interface ORTPG262Model (private)
- (void) runStarted:(NSNotification*)aNote;
- (void) runStopped:(NSNotification*)aNote;
- (void) timeout;
- (void) processOneCommandFromQueue;
- (void) process_response:(NSString*)theResponse;
- (void) pollPressures;
@end

@implementation ORTPG262Model
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
	for(i=0;i<2;i++){
		[timeRates[i] release];
	}

	[super dealloc];
}

- (void) setUpImage
{
	[self setImage:[NSImage imageNamed:@"TPG262.tif"]];
}

- (void) makeMainController
{
	[self linkToController:@"ORTPG262Controller"];
}

- (NSString*) helpURL
{
	return @"RS232/TPG262.html";
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
        NSString* theString = [[[[NSString alloc] initWithData:[[note userInfo] objectForKey:@"data"] 
												      encoding:NSASCIIStringEncoding] autorelease] uppercaseString];

 		//the serial port may break the data up into small chunks, so we have to accumulate the chunks until
		//we get a full piece.       
		if(!buffer)buffer = [[NSMutableString string] retain];
        [buffer appendString:theString];	
		
		if([buffer hasSuffix:@"\r\n"]){
			//got a full chunk ... process according to the port data state
			if(portDataState == kWaitingForACK){
				if([buffer characterAtIndex:0] == kNAK){
					//error in transimission
					//flush and go to next command
					NSLogError(@"Transmission Error",@"TGP262",nil);
					[self setLastRequest:nil];			 //clear the last request
					[self processOneCommandFromQueue];	 //do the next command in the queue
				}
				else if([buffer characterAtIndex:0] == kACK){
					//device has sent us a positive aknowledgement of the command
					//respond with a request to transmit data and enter new state
					[serialPort writeString:[NSString stringWithFormat:@"%c",kENQ]];
					portDataState = kProcessData;
				}
			}
			else if(portDataState == kProcessData){
				//OK, should be valid data. Process and continue with the que
				[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeout) object:nil];
				[self process_response:buffer];
				[self setLastRequest:nil];			 //clear the last request
				[self processOneCommandFromQueue];	 //do the next command in the queue
			}
			//flush the accumulation buffer
			[buffer release];
			buffer = nil;
		}
	}
}


- (void) shipPressureValues
{
    if([[ORGlobal sharedGlobal] runInProgress]){
		
		unsigned long data[6];
		data[0] = dataId | 6;
		data[1] = [self uniqueIdNumber]&0xfff;
		
		union {
			float asFloat;
			unsigned long asLong;
		}theData;
		int index = 2;
		int i;
		for(i=0;i<2;i++){
			theData.asFloat = pressure[i];
			data[index] = theData.asLong;
			index++;
			
			data[index] = timeMeasured[i];
			index++;
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:ORQueueRecordForShippingNotification 
															object:[NSData dataWithBytes:data length:sizeof(long)*6]];
	}
}


#pragma mark •••Accessors

- (int) measurementState
{
    return measurementState;
}

- (void) setMeasurementState:(int)aMeasurementState
{
    measurementState = aMeasurementState;
}

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

    [[NSNotificationCenter defaultCenter] postNotificationName:ORTPG262ModelPressureScaleChanged object:self];
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

    [[NSNotificationCenter defaultCenter] postNotificationName:ORTPG262ModelShipPressuresChanged object:self];
}

- (int) pollTime
{
    return pollTime;
}

- (void) setPollTime:(int)aPollTime
{
    [[[self undoManager] prepareWithInvocationTarget:self] setPollTime:pollTime];
    pollTime = aPollTime;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORTPG262ModelPollTimeChanged object:self];

	if(pollTime){
		[self performSelector:@selector(pollPressures) withObject:nil afterDelay:2];
	}
	else {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pollPressures) object:nil];
	}
}


- (float) pressure:(int)index
{
	if(index>=0 && index<2)return pressure[index];
	else return 0.0;
}

- (unsigned long) timeMeasured:(int)index
{
	if(index>=0 && index<2)return timeMeasured[index];
	else return 0;
}

- (void) setPressure:(int)index value:(float)aValue;
{
	if(index>=0 && index<2){
		pressure[index] = aValue;
		//get the time(UT!)
		time_t	ut_Time;
		time(&ut_Time);
		//struct tm* theTimeGMTAsStruct = gmtime(&theTime);
		timeMeasured[index] = ut_Time;

		[[NSNotificationCenter defaultCenter] postNotificationName:ORTPG262PressureChanged 
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

    [[NSNotificationCenter defaultCenter] postNotificationName:ORTPG262ModelPortNameChanged object:self];
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

    [[NSNotificationCenter defaultCenter] postNotificationName:ORTPG262ModelSerialPortChanged object:self];
}

- (void) openPort:(BOOL)state
{
    if(state) {
        [serialPort open];
		[serialPort setSpeed:9600];
		[serialPort setParityNone];
		[serialPort setStopBits2:0];
		[serialPort setDataBits:8];
		[serialPort commitChanges];
    }
    else      [serialPort close];
    portWasOpen = [serialPort isOpen];
    [[NSNotificationCenter defaultCenter] postNotificationName:ORTPG262ModelPortStateChanged object:self];
}


#pragma mark •••Archival
- (id) initWithCoder:(NSCoder*)decoder
{
	self = [super initWithCoder:decoder];
	[[self undoManager] disableUndoRegistration];
	[self setPressureScale:	[decoder decodeIntForKey:@"ORTPG262ModelPressureScale"]];
	[self setShipPressures:	[decoder decodeBoolForKey:@"ORTPG262ModelShipPressures"]];
	[self setPollTime:		[decoder decodeIntForKey:@"ORTPG262ModelPollTime"]];
	[self setPortWasOpen:	[decoder decodeBoolForKey:@"ORTPG262ModelPortWasOpen"]];
    [self setPortName:		[decoder decodeObjectForKey: @"portName"]];
	[[self undoManager] enableUndoRegistration];
	int i;
	for(i=0;i<2;i++){
		timeRates[i] = [[ORTimeRate alloc] init];
	}
    [self registerNotificationObservers];

	return self;
}
- (void) encodeWithCoder:(NSCoder*)encoder
{
    [super encodeWithCoder:encoder];
    [encoder encodeInteger:pressureScale	forKey:@"ORTPG262ModelPressureScale"];
    [encoder encodeBool:shipPressures	forKey:@"ORTPG262ModelShipPressures"];
    [encoder encodeInteger:pollTime			forKey:@"ORTPG262ModelPollTime"];
    [encoder encodeBool:portWasOpen		forKey:@"ORTPG262ModelPortWasOpen"];
    [encoder encodeObject:portName		forKey: @"portName"];
}

#pragma mark ••• Commands
- (void) addCmdToQueue:(NSString*)aCmd
{
    if([serialPort isOpen]){ 
		if(!cmdQueue)cmdQueue = [[ORSafeQueue alloc] init];
		[cmdQueue enqueue:aCmd];
		if(!lastRequest){
			[self processOneCommandFromQueue];
		}
	}
}

- (void) readPressures
{
	[self addCmdToQueue:@"PRX"];
	[self addCmdToQueue:@"++ShipRecords"];
}

#pragma mark •••Data Records
- (unsigned long) dataId { return dataId; }
- (void) setDataId: (unsigned long) DataId
{
    dataId = DataId;
}
- (void) setDataIds:(id)assigner
{
    dataId       = [assigner assignDataIds:kLongForm];
}

- (void) syncDataIdsWith:(id)anotherTPG262
{
    [self setDataId:[anotherTPG262 dataId]];
}

- (void) appendDataDescription:(ORDataPacket*)aDataPacket userInfo:(NSDictionary*)userInfo
{
    //----------------------------------------------------------------------------------------
    // first add our description to the data description
    [aDataPacket addDataDescriptionItem:[self dataRecordDescription] forKey:@"TPG262Model"];
}

- (NSDictionary*) dataRecordDescription
{
    NSMutableDictionary* dataDictionary = [NSMutableDictionary dictionary];
    NSDictionary* aDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
        @"ORTPG262DecoderForPressure",     @"decoder",
        [NSNumber numberWithLong:dataId],   @"dataId",
        [NSNumber numberWithBool:NO],       @"variable",
        [NSNumber numberWithLong:6],        @"length",
        nil];
    [dataDictionary setObject:aDictionary forKey:@"Pressures"];
    
    return dataDictionary;
}

@end

@implementation ORTPG262Model (private)
- (void) runStarted:(NSNotification*)aNote
{
}

- (void) runStopped:(NSNotification*)aNote
{
}

- (void) timeout
{
	NSLogError(@"command timeout",@"TGP262",nil);
	[self setLastRequest:nil];
	[cmdQueue removeAllObjects];
	[self processOneCommandFromQueue];	 //do the next command in the queue
}

- (void) processOneCommandFromQueue
{
	NSString* aCmd = [cmdQueue dequeue];
	if(aCmd){
		if([aCmd isEqualToString:@"++ShipRecords"]){
			if(shipPressures) [self shipPressureValues];
		}
		else {
			if(![aCmd hasSuffix:@"\r\n"]) {
				aCmd = [aCmd stringByReplacingOccurrencesOfString:@"\n" withString:@""];
				aCmd = [aCmd stringByReplacingOccurrencesOfString:@"\r" withString:@""];
				aCmd = [aCmd stringByAppendingString:@"\r\n"];
			}
			[self setLastRequest:aCmd];
			[self performSelector:@selector(timeout) withObject:nil afterDelay:3];
			//just sent a command so the first thing received should be an ACK
			//enter that state and send the command
			portDataState = kWaitingForACK;
			[serialPort writeString:aCmd];
		}
	}
}

- (void) process_response:(NSString*)theResponse
{
	theResponse = [theResponse stringByReplacingOccurrencesOfString:@"\n" withString:@""];
	theResponse = [theResponse stringByReplacingOccurrencesOfString:@"\r" withString:@""];
	if([lastRequest hasPrefix:@"PR"]){
		NSArray* parts = [theResponse componentsSeparatedByString:@","];
		int n = (int)[parts count];
		if(n >= 2){
			[self setMeasurementState:[[parts objectAtIndex:0] intValue]];
			int i;
			for(i=0;i<n;i++){
				float thePressure = 0;
				if(measurementState == kTPG262MeasurementOK){
					thePressure = [[parts objectAtIndex:i+1] floatValue];
				}
				[self setPressure:i value:thePressure];
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
