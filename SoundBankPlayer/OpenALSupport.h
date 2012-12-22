
// Modified from Apple's oalTouch sample code.

#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/ExtendedAudioFile.h>
#import <OpenAL/al.h>
#import <OpenAL/alc.h>

typedef ALvoid AL_APIENTRY (*alBufferDataStaticProcPtr)(const ALint bid, ALenum format, ALvoid *data, ALsizei size, ALsizei freq);
ALvoid alBufferDataStaticProc(const ALint bid, ALenum format, ALvoid *data, ALsizei size, ALsizei freq);

typedef ALvoid AL_APIENTRY (*alcMacOSXMixerOutputRateProcPtr)(const ALdouble value);
ALvoid alcMacOSXMixerOutputRateProc(const ALdouble value);

void *GetOpenALAudioData(CFURLRef inFileURL, ALsizei *outDataSize, ALenum *outDataFormat, ALsizei *outSampleRate);
