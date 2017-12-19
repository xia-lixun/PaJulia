module QUICKANNO

import WAV
include("D:/Git/dnn/src/julia/data.jl")


# path: path contain wav files to be labeled, no sub folders are allowed
# block: minimal seconds of one block
# return: {"m0195fx+2pt7WZBYeeI.wav" => [0.wav, 1.wav, ..., n.wav]}
# side effects: temp/QuickAnno48/m0195fx+2pt7WZBYeeI.wav/0.wav
#                                                       /1.wav
#                                                       /...
#                                                       /n.wav
function fragmentation(path::String, block::Float64)
    
    p16 = joinpath(tempdir(), "QuickAnno16")
    p48 = joinpath(tempdir(), "QuickAnno48")
    rm(p16, force=true, recursive=true)
    rm(p48, force=true, recursive=true)
    mkpath(p16)

    decomp = Dict{String,Array{String,1}}()
    files = DATA.list(path, t=".wav")

    for j in files
        local (x,sr) = WAV.wavread(j)
        local n = size(x,1)
        local sps::Int64 = Int64(round(sr * block))

        local bn = basename(j)
        local ps = joinpath(p16,bn)
        mkdir(ps)

        local q = div(n,sps) - 1
        decomp[bn] = ["$k.wav" for k = 0:q]

        for k = 0:q-1
            WAV.wavwrite(hcat(view(x,k*sps+1:(k+1)*sps,:), view(x,k*sps+1:(k+1)*sps,:)), joinpath(ps,"$k.wav"), Fs=sr, nbits=32)
        end
        WAV.wavwrite(hcat(view(x,q*sps+1:n,:),view(x,q*sps+1:n,:)), joinpath(ps,"$q.wav"), Fs=sr, nbits=32)
    end

    DATA.resample(p16, p48, 48000)
    rm(p16, force=true, recursive=true)
    decomp
end







function label!(decomp::Dict{String,Array{String,1}})
    
    function state_play(clip::String)
        ccall((:play, "PaDynamic"), Int32, (Ptr{UInt8}, Int32), clip, 48000)
        info("Guess what?")
        cmd = lowercase(readline(STDIN))
        cmd == "y" && return true
        cmd == "n" && return false
        return state_play(clip)
    end

    p = joinpath(tempdir(), "QuickAnno48")

    maxdepth = 0
    for i in keys(decomp)
        length(decomp[i]) > maxdepth && (maxdepth = length(decomp[i]))
    end
    info("max depth: $maxdepth")

    for i = 0:maxdepth-1
        for j in keys(decomp)
            if in("$i.wav",decomp[j])
                play = joinpath(p,j,"$i.wav")
                flag = state_play(play)
                flag && (pop!(decomp,j);info("$j spotted"))
            end
        end
    end
    nothing
end



function quickanno(path::String, block::Float64)
    dp = fragmentation(path, block)
    label!(dp)
    dst = joinpath(path,"nospeech")
    mkpath(dst)
    for i in keys(dp)
        mv(joinpath(path,i), joinpath(dst,i), remove_destination=true)
    end
    nothing
end


## module end
end