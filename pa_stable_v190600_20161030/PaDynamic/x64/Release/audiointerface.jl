using WAV


# portaudio interfaces:
# 1. playrecord(const char * path_play, const char * path_record, int sample_rate, int channels_record, int bits_record)
# 2. play(const char * path, int sample_rate)
# 3. record(const char * path, int sample_rate, int channels, double duration, int bits)


# path   : the root path of the recording
# rate   : the sample rate
# channel: the selected channel of the soundcard
# t      : time duration
# id     : the name string assigned
#
# example: record("D:\\git\\spl\\calibration\\", 48000, [2,5,8], "40AG-201709221637")
function record(path, id, rate, channel, t)
    fulltrack = joinpath(path, "tmp.wav")
    ccall((:record, "PaDynamic"), Int32, (Ptr{UInt8}, Int32, Int32, Float64, Int32), fulltrack, rate, 8, t, 32)
    x,fs = wavread(fulltrack)
    wavwrite(x[:,channel], joinpath(path, "$id.wav"), Fs=fs, nbits=32)
    rm(fulltrack)
end


