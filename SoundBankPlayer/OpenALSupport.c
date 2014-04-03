
#include "OpenALSupport.h"

ALvoid alBufferDataStaticProc(const ALint bid, ALenum format, ALvoid *data, ALsizei size, ALsizei freq)
{
	static alBufferDataStaticProcPtr proc = NULL;

	if (proc == NULL)
		proc = (alBufferDataStaticProcPtr)alcGetProcAddress(NULL, (const ALCchar *)"alBufferDataStatic");

	if (proc != NULL)
		proc(bid, format, data, size, freq);
}

ALvoid alcMacOSXMixerOutputRateProc(const ALdouble value)
{
	static alcMacOSXMixerOutputRateProcPtr proc = NULL;

	if (proc == NULL)
		proc = (alcMacOSXMixerOutputRateProcPtr)alcGetProcAddress(NULL, (const ALCchar *)"alcMacOSXMixerOutputRate");

	if (proc != NULL)
		proc(value);
}

void *GetOpenALAudioData(CFURLRef inFileURL, ALsizei *outDataSize, ALenum *outDataFormat, ALsizei *outSampleRate)
{
	OSStatus err = noErr;

	ExtAudioFileRef extRef = NULL;
	err = ExtAudioFileOpenURL(inFileURL, &extRef);
	if (err != noErr)
	{
		printf("GetOpenALAudioData: ExtAudioFileOpenURL FAILED, Error = %d\n", (int)err);
		return NULL;
	}

	AudioStreamBasicDescription theFileFormat;
	UInt32 thePropertySize = sizeof(theFileFormat);
	err = ExtAudioFileGetProperty(extRef, kExtAudioFileProperty_FileDataFormat, &thePropertySize, &theFileFormat);
	if (err != noErr)
	{
		printf("GetOpenALAudioData: ExtAudioFileGetProperty(kExtAudioFileProperty_FileDataFormat) FAILED, Error = %d\n", (int)err);
		ExtAudioFileDispose(extRef);
		return NULL;
	}

	if (theFileFormat.mChannelsPerFrame > 2)
	{
		printf("GetOpenALAudioData: Unsupported format, channel count is greater than stereo\n");
		ExtAudioFileDispose(extRef);
		return NULL;
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
		printf("GetOpenALAudioData: ExtAudioFileSetProperty(kExtAudioFileProperty_ClientDataFormat) FAILED, Error = %d\n", (int)err);
		ExtAudioFileDispose(extRef);
		return NULL;
	}

	SInt64 theFileLengthInFrames = 0;
	thePropertySize = sizeof(theFileLengthInFrames);
	err = ExtAudioFileGetProperty(extRef, kExtAudioFileProperty_FileLengthFrames, &thePropertySize, &theFileLengthInFrames);
	if (err != noErr)
	{
		printf("GetOpenALAudioData: ExtAudioFileGetProperty(kExtAudioFileProperty_FileLengthFrames) FAILED, Error = %d\n", (int)err);
		ExtAudioFileDispose(extRef);
		return NULL;
	}

	UInt32 dataSize = (UInt32)theFileLengthInFrames * theOutputFormat.mBytesPerFrame;
	void *theData = malloc(dataSize);
	if (theData == NULL)
	{
		printf("GetOpenALAudioData: malloc FAILED\n");
		ExtAudioFileDispose(extRef);
		return NULL;
	}

	AudioBufferList theDataBuffer;
	theDataBuffer.mNumberBuffers = 1;
	theDataBuffer.mBuffers[0].mDataByteSize = dataSize;
	theDataBuffer.mBuffers[0].mNumberChannels = theOutputFormat.mChannelsPerFrame;
	theDataBuffer.mBuffers[0].mData = theData;

	err = ExtAudioFileRead(extRef, (UInt32 *)&theFileLengthInFrames, &theDataBuffer);
	if (err != noErr)
	{ 
		printf("GetOpenALAudioData: ExtAudioFileRead FAILED, Error = %d\n", (int)err);
		free(theData);
		ExtAudioFileDispose(extRef);
		return NULL;
	}

	*outDataSize = (ALsizei)dataSize;
	*outDataFormat = (theOutputFormat.mChannelsPerFrame > 1) ? AL_FORMAT_STEREO16 : AL_FORMAT_MONO16;
	*outSampleRate = (ALsizei)theOutputFormat.mSampleRate;

	ExtAudioFileDispose(extRef);
	return theData;
}
