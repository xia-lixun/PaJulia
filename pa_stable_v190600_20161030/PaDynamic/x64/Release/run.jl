using WAV
using Plots

include("expsweep.jl")


fs = 48000
f0 = 20
f1 = fs/2
ess = exp_sine_sweep(f0, f1, 5, fs)

play = "ess.wav"
rec = "ess_res.wav"

wavwrite(ess, play, Fs=fs, nbits=32)
ccall((:playrecord, "PaDynamic"), Int32, (Ptr{UInt8}, Ptr{UInt8}, Int32, Int32, Int32), play, rec, fs, 1, 32)
ess_res, fs_ = wavread(rec)
assert(convert(Int64,fs_) == fs)

impulse = decode_impulse(ess, f0, f1, ess_res[:,1])
plot(impulse, size=(1200,800))


# extern "C" PA_DYNAMIC_API int play(const char * path, int sample_rate);
# extern "C" PA_DYNAMIC_API int record(const char * path, int sample_rate, int channels, double duration, int bits);
# extern "C" PA_DYNAMIC_API int playrecord(const char * path_play, const char * path_record, int sample_rate, int channels_record, int bits_record);