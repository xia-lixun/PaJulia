/** @file PaTask.cpp
	@ingroup PaDynamic
	@brief Portaudio wrapper for dynamic languages: Julia/Matlab etc.
	@author Lixun Xia <lixun.xia2@harman.com>
*/

#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <string>
#include <cassert>
#include "./CsWav.h"
#include "../include/portaudio.h"
#include "./PaTask.h"


#define FRAMES_PER_BUFFER	(64)






class PaPlay
{
public:
    PaPlay(std::string path_to_play, size_t process_sample_rate) : stream(0), spk_frame(0)
    {
		//init playback wav source
		size_t head_bytes = spk_wav.ExtractMetaInfo(path_to_play.c_str());
		spk_wav.PrintMetaInfo();
		assert(spk_wav.GetSampleRate() == process_sample_rate);
		sample_rate = process_sample_rate;
		spk_totsps = spk_wav.GetFrameLength() * spk_wav.GetNumChannel();

		//load the playback data from the wav
		spk_dat = spk_wav.GetFrameMatrix(path_to_play.c_str());

		//log status string
        sprintf( message, "ctor ok" );
    }


    bool open(PaDeviceIndex index)
    {
        PaStreamParameters outputParameters;
        outputParameters.device = index;
        if (outputParameters.device == paNoDevice)
            return false;
        const PaDeviceInfo* pInfo = Pa_GetDeviceInfo(index);
        if (pInfo != 0)
            printf("Output device name: '%s'\r", pInfo->name);

        outputParameters.channelCount = (int)(spk_wav.GetNumChannel());         /* dependes on the wav file */
        outputParameters.sampleFormat = paFloat32;                              /* CsWav will alway ensure 32 bit float format */
        outputParameters.suggestedLatency = Pa_GetDeviceInfo( outputParameters.device )->defaultLowOutputLatency;
        outputParameters.hostApiSpecificStreamInfo = NULL;

		//frames per buffer can also be "paFramesPerBufferUnspecified"
		//Using 'this' for userData so we can cast to PaPlay* in paCallback method
        if (paNoError != Pa_OpenStream(&stream, NULL, &outputParameters, sample_rate, FRAMES_PER_BUFFER, paClipOff, &PaPlay::paCallback, this))
            return false;
        if (paNoError != Pa_SetStreamFinishedCallback(stream, &PaPlay::paStreamFinished))
        {
            Pa_CloseStream( stream );
            stream = 0;
            return false;
        }
        return true;
    }


	bool info()
	{
		if (stream == 0)
			return false;
		const PaStreamInfo * stream_info = Pa_GetStreamInfo(stream);
		printf("PaStreamInfo: struct version = %d\n", stream_info->structVersion);
		printf("PaStreamInfo: input latency = %f second\n", stream_info->inputLatency);
		printf("PaStreamInfo: output latency = %f second\n", stream_info->outputLatency);
		printf("PaStreamInfo: sample rate = %f sps\n", stream_info->sampleRate);
		return paNoError;
	}


    bool close()
    {
        if (stream == 0)
            return false;
        PaError err = Pa_CloseStream( stream );
        stream = 0;
        return (err == paNoError);
    }

    bool start()
    {
        if (stream == 0)
            return false;
        PaError err = Pa_StartStream( stream );
        return (err == paNoError);
    }

	bool pending()
	{
		if (stream == 0)
			return false;
		printf("\n");
		while (Pa_IsStreamActive(stream))
		{
			printf("\rcpu load:[%f], patime[%f]", cpuload, timebase); fflush(stdout);
			Pa_Sleep(250);
		}
		return paNoError;
	}

    bool stop()
    {
        if (stream == 0)
            return false;
        PaError err = Pa_StopStream( stream );
        return (err == paNoError);
    }


	volatile double cpuload;
	volatile PaTime timebase;

private:
    /* The instance callback, where we have access to every method/variable in object of class PaPlay */
    int paCallbackMethod(
		const void *inputBuffer, 
		void *outputBuffer,
        unsigned long framesPerBuffer,
        const PaStreamCallbackTimeInfo* timeInfo,
        PaStreamCallbackFlags statusFlags)
    {
        float *out = (float*)outputBuffer;
        unsigned long i;

        (void) timeInfo; /* Prevent unused variable warnings. */
        (void) statusFlags;
        (void) inputBuffer;

        for( i = 0; i < framesPerBuffer; i++ )
        {
			memcpy(out, &spk_dat[spk_frame], spk_wav.GetNumChannel() * sizeof(float));
			out += ((int)(spk_wav.GetNumChannel()));
			spk_frame += (spk_wav.GetNumChannel());
			if (spk_frame >= spk_totsps)
			{
				memset(out, 0, (framesPerBuffer-i-1) * (spk_wav.GetNumChannel()) * sizeof(float));
				spk_frame = 0;
				return paComplete;
			}
        }

		//update utility features
		cpuload = Pa_GetStreamCpuLoad(stream);
		timebase = Pa_GetStreamTime(stream);

        return paContinue;
    }

    /* This routine will be called by the PortAudio engine when audio is needed.
    ** It may called at interrupt level on some machines so don't do anything
    ** that could mess up the system like calling malloc() or free().
    */
    static int paCallback( 
		const void *inputBuffer, 
		void *outputBuffer,
        unsigned long framesPerBuffer,
        const PaStreamCallbackTimeInfo* timeInfo,
        PaStreamCallbackFlags statusFlags,
        void *userData )
    {
        /* Here we cast userData to PaPlay* type so we can call the instance method paCallbackMethod, we can do that since 
           we called Pa_OpenStream with 'this' for userData */
        return ((PaPlay*)userData)->paCallbackMethod(inputBuffer, outputBuffer, framesPerBuffer, timeInfo, statusFlags);
    }




    void paStreamFinishedMethod()
    {
        printf( "Stream Completed: %s\n", message );
    }

    /*
     * This routine is called by portaudio when playback is done.
     */
    static void paStreamFinished(void* userData)
    {
        return ((PaPlay*)userData)->paStreamFinishedMethod();
    }


	CsWav spk_wav;
	const float *spk_dat;
	size_t spk_frame;
	size_t spk_totsps;

	size_t sample_rate;
	PaStream *stream;
    char message[20];
};

class ScopedPaHandler
{
public:
    ScopedPaHandler()
        : _result(Pa_Initialize())
    {
    }
    ~ScopedPaHandler()
    {
        if (_result == paNoError)
            Pa_Terminate();
    }

    PaError result() const { return _result; }

private:
    PaError _result;
};








/*******************************************************************/
//int main(void);
//int main(void)
int play(const char * path, int sample_rate)
{
	printf("PortAudio Test: output PaPlay wave. SR = %d, BufSize = %d\n", 48000, FRAMES_PER_BUFFER);
    //PaPlay PaPlay("D:\\pa_stable_v190600_20161030\\PaDynamic\\8_Channel_ID.wav", 48000);
	std::string spath(path);
	PaPlay PaPlay(spath, sample_rate);

	ScopedPaHandler paInit;
    if( paInit.result() != paNoError ) 
		goto error;

    if (PaPlay.open(Pa_GetDefaultOutputDevice()))
    {
		PaPlay.info();
        if (PaPlay.start())
        {    
			PaPlay.pending();
            PaPlay.stop();
        }
        PaPlay.close();
    }
    return paNoError;

error:
    fprintf( stderr, "An error occured while using the portaudio stream\n" );
    fprintf( stderr, "Error number: %d\n", paInit.result() );
    fprintf( stderr, "Error message: %s\n", Pa_GetErrorText( paInit.result() ) );
    return 1;
}

