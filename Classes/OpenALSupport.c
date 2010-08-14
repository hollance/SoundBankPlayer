/*

(Modified from Apple's oalTouch sample code.)

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
Inc. ("Apple") in consideration of your agreement to the following
terms, and your use, installation, modification or redistribution of
this Apple software constitutes acceptance of these terms.  If you do
not agree with these terms, please do not use, install, modify or
redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software.
Neither the name, trademarks, service marks or logos of Apple Inc. may
be used to endorse or promote products derived from the Apple Software
without specific prior written permission from Apple.  Except as
expressly stated in this notice, no other rights or licenses, express or
implied, are granted by Apple herein, including but not limited to any
patent rights that may be infringed by your derivative works or by other
works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright (C) 2010 Apple Inc. All Rights Reserved.

*/

#include "OpenALSupport.h"

ALvoid alBufferDataStaticProc(const ALint bid, ALenum format, ALvoid* data, ALsizei size, ALsizei freq)
{
	static alBufferDataStaticProcPtr proc = NULL;

	if (proc == NULL)
		proc = (alBufferDataStaticProcPtr) alcGetProcAddress(NULL, (const ALCchar*) "alBufferDataStatic");

	if (proc != NULL)
		proc(bid, format, data, size, freq);
}

ALvoid alcMacOSXMixerOutputRateProc(const ALdouble value)
{
	static alcMacOSXMixerOutputRateProcPtr proc = NULL;

	if (proc == NULL)
		proc = (alcMacOSXMixerOutputRateProcPtr) alcGetProcAddress(NULL, (const ALCchar*) "alcMacOSXMixerOutputRate");

	if (proc != NULL)
		proc(value);
}

void* GetOpenALAudioData(CFURLRef inFileURL, ALsizei* outDataSize, ALenum* outDataFormat, ALsizei* outSampleRate)
{
	OSStatus err = noErr;
	void* theData = NULL;

	ExtAudioFileRef extRef = NULL;
	err = ExtAudioFileOpenURL(inFileURL, &extRef);
	if (err != noErr)
	{
		printf("GetOpenALAudioData: ExtAudioFileOpenURL FAILED, Error = %ld\n", err);
		goto Exit;
	}

	AudioStreamBasicDescription theFileFormat;
	UInt32 thePropertySize = sizeof(theFileFormat);
	err = ExtAudioFileGetProperty(extRef, kExtAudioFileProperty_FileDataFormat, &thePropertySize, &theFileFormat);
	if (err != noErr)
	{
		printf("GetOpenALAudioData: ExtAudioFileGetProperty(kExtAudioFileProperty_FileDataFormat) FAILED, Error = %ld\n", err);
		goto Exit;
	}

	if (theFileFormat.mChannelsPerFrame > 2)
	{
		printf("GetOpenALAudioData: Unsupported format, channel count is greater than stereo\n");
		goto Exit;
	}

	// Set the output format to 16 bit signed integer (native-endian) data
	// Maintain the channel count and sample rate of the original source format
	AudioStreamBasicDescription theOutputFormat;
	theOutputFormat.mSampleRate = theFileFormat.mSampleRate;
	theOutputFormat.mChannelsPerFrame = theFileFormat.mChannelsPerFrame;
	theOutputFormat.mFormatID = kAudioFormatLinearPCM;
	theOutputFormat.mBytesPerPacket = 2 * theOutputFormat.mChannelsPerFrame;
	theOutputFormat.mFramesPerPacket = 1;
	theOutputFormat.mBytesPerFrame = 2 * theOutputFormat.mChannelsPerFrame;
	theOutputFormat.mBitsPerChannel = 16;
	theOutputFormat.mFormatFlags = kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger;

	err = ExtAudioFileSetProperty(extRef, kExtAudioFileProperty_ClientDataFormat, sizeof(theOutputFormat), &theOutputFormat);
	if (err != noErr)
	{
		printf("GetOpenALAudioData: ExtAudioFileSetProperty(kExtAudioFileProperty_ClientDataFormat) FAILED, Error = %ld\n", err);
		goto Exit;
	}

	SInt64 theFileLengthInFrames = 0;
	thePropertySize = sizeof(theFileLengthInFrames);
	err = ExtAudioFileGetProperty(extRef, kExtAudioFileProperty_FileLengthFrames, &thePropertySize, &theFileLengthInFrames);
	if (err != noErr)
	{
		printf("GetOpenALAudioData: ExtAudioFileGetProperty(kExtAudioFileProperty_FileLengthFrames) FAILED, Error = %ld\n", err);
		goto Exit;
	}

	UInt32 dataSize = theFileLengthInFrames * theOutputFormat.mBytesPerFrame;
	theData = malloc(dataSize);
	if (theData == NULL)
	{
		printf("GetOpenALAudioData: malloc FAILED\n");
		goto Exit;
	}

	AudioBufferList theDataBuffer;
	theDataBuffer.mNumberBuffers = 1;
	theDataBuffer.mBuffers[0].mDataByteSize = dataSize;
	theDataBuffer.mBuffers[0].mNumberChannels = theOutputFormat.mChannelsPerFrame;
	theDataBuffer.mBuffers[0].mData = theData;

	err = ExtAudioFileRead(extRef, (UInt32*)&theFileLengthInFrames, &theDataBuffer);
	if (err != noErr)
	{ 
		free(theData);
		theData = NULL;  // make sure to return NULL
		printf("GetOpenALAudioData: ExtAudioFileRead FAILED, Error = %ld\n", err);
		goto Exit;
	}	

	*outDataSize = (ALsizei)dataSize;
	*outDataFormat = (theOutputFormat.mChannelsPerFrame > 1) ? AL_FORMAT_STEREO16 : AL_FORMAT_MONO16;
	*outSampleRate = (ALsizei)theOutputFormat.mSampleRate;

Exit:
	if (extRef != NULL)
		ExtAudioFileDispose(extRef);

	return theData;
}
