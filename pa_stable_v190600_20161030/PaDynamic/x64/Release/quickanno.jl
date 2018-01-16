module QUICKANNO

import WAV
import HDF5

include("D:/Git/dnn/src/julia/data.jl")
include("D:/Git/dnn/src/julia/forward.jl")
include("D:/Git/dnn/src/julia/ui.jl")


# path: path contain wav files to be labeled, no sub folders are allowed
# block: minimal seconds of one block
# return: {"m0195fx+2pt7WZBYeeI.wav" => [0.wav, 1.wav, ..., n.wav]}
# side effects: temp/QuickAnno48/m0195fx+2pt7WZBYeeI.wav/0.wav
#                                                       /1.wav
#                                                       /...
#                                                       /n.wav
function fragmentation(path::String, block::Float64)
    
    p16mono = joinpath(tempdir(), randstring(rand(4:32)))
    p16 = joinpath(tempdir(), randstring(rand(4:32)))
    p48 = joinpath(tempdir(), randstring(rand(4:32)))

    rm(p16mono, force=true, recursive=true)
    rm(p16, force=true, recursive=true)
    rm(p48, force=true, recursive=true)
    mkpath(p16)
    mkpath(p16mono)

    decomp = Dict{String,Array{String,1}}()
    files = DATA.list(path, t=".wav")

    for j in files
        local (x,sr) = WAV.wavread(j)
        local n = size(x,1)
        local sps::Int64 = Int64(round(sr * block))
        n < 2sps && continue

        local bn = basename(j)
        local ps = joinpath(p16,bn)
        local psm = joinpath(p16mono,bn)
        mkdir(ps)
        mkdir(psm)

        local q = div(n,sps) - 1
        decomp[bn] = ["$k.wav" for k = 0:q]

        for k = 0:q-1
            WAV.wavwrite(view(x,k*sps+1:(k+1)*sps,:), joinpath(psm,"$k.wav"), Fs=sr, nbits=32)
            WAV.wavwrite(hcat(view(x,k*sps+1:(k+1)*sps,:), view(x,k*sps+1:(k+1)*sps,:)), joinpath(ps,"$k.wav"), Fs=sr, nbits=32)
        end
        WAV.wavwrite(view(x,q*sps+1:n,:), joinpath(psm,"$q.wav"), Fs=sr, nbits=32)
        WAV.wavwrite(hcat(view(x,q*sps+1:n,:),view(x,q*sps+1:n,:)), joinpath(ps,"$q.wav"), Fs=sr, nbits=32)
    end

    DATA.resample(p16, p48, 48000)
    rm(p16, force=true, recursive=true)
    (decomp, p16mono, p48)
end


# @16000 sps
function vad(clip::String)
    rm("vstcla_smvad.txt", force=true)
    try
        run(`vad.exe $clip vstfea.txt fileLabel_Train_1000_16000.model vstcla.txt 256 512`)
    catch
    end
    return mean(readdlm("vstcla_smvad.txt"))
end



function vad(
    clip::String,
    nn::FORWARD.TF{Float32},
    nfft::Int64, 
    nhp::Int64,
    ntxt::Int64, 
    nat::Int64,
    μ::Array{Float32,1}, 
    σ::Array{Float32,1}
    )
    x, sr = WAV.wavread(clip)
    x = Float32.(x)
    bm = FORWARD.bm_inference(nn, view(x,:,1), nfft, nhp, ntxt, nat, μ, σ)
    mean(bm)
end





function label(dp::Dict{String,Array{String,1}}, p16, p48)
    
    nn = FORWARD.TF{Float32}("D:\\5-Workspace\\1-Model\\20180105\\model-20180105.mat")
    μ = HDF5.h5read("D:\\5-Workspace\\1-Model\\20180105\\stat.h5", "mu")
    σ = HDF5.h5read("D:\\5-Workspace\\1-Model\\20180105\\stat.h5", "std")
    μ = Float32.(μ)
    σ = Float32.(σ)

    function state_play(clip::String, depth)
        ccall((:play, "PaDynamic"), Int32, (Ptr{UInt8}, Int32), clip, 48000)
        info("[$depth/$maxdepth] Sounds like speech? [y/n/REPLAY]")
        cmd = lowercase(readline(STDIN))
        cmd == "y" && return true
        cmd == "n" && return false
        return state_play(clip, depth)
    end

    # p16 = joinpath(tempdir(), "QuickAnno16mono")
    # p48 = joinpath(tempdir(), "QuickAnno48")

    # priority via vad
    dpp = Dict{String,Array{Tuple{String,Float64},1}}()
    n = length(dp)
    pr = UI.Progress(10)
    for (k,i) in enumerate(keys(dp))
        # dpp[i] = [(j,vad(joinpath(p16,i,j))) for j in dp[i]]
        dpp[i] = [(j,vad(joinpath(p16,i,j), nn, 512, 128, 23, 14, μ, σ)) for j in dp[i]]
        sort!(dpp[i], by=x->x[2], rev=true)
        UI.update(pr, k, n)
    end


    maxdepth = 0
    for i in keys(dp)
        length(dp[i]) > maxdepth && (maxdepth = length(dp[i]))
    end
    info("max depth: $maxdepth")

    for i = 1:maxdepth
        for j in keys(dpp)
            if i <= length(dpp[j])
                flag = state_play(joinpath(p48,j,dpp[j][i][1]),i)
                flag && (pop!(dpp,j);info("$j spotted"))
            end
        end
        info("Layer $i complete. Proceed? [no/YES]")
        lowercase(readline(STDIN)) == "no" && break
    end
    dpp
end




function current_set(path::String)
    uid = Set{String}()
    google = DATA.list(path, t = ".wav")

    for i in google
        b = split(basename(i),'+')
        push!(uid, String(b[2][1:end-4]))
    end
    uid
end








function quickanno(path::String, block::Float64)

    uid = current_set("D:\\5-Workspace\\GoogleAudioSet\\")
    subset = DATA.list(path, t=".wav")
    for i in subset
        b = split(basename(i),'+')
        if in(String(b[2][1:end-4]),uid)
            rm(i)
            info("duplicate $i")
        end
    end
    info("press any key to continue...")
    cmd = lowercase(readline(STDIN))

    dp,path16,path48 = fragmentation(path, block)
    dpp = label(dp, path16, path48)
    dst = joinpath(path,"nospeech")
    mkpath(dst)
    for i in keys(dpp)
        mv(joinpath(path,i), joinpath(dst,i), remove_destination=true)
    end

    rm(path16, force=true, recursive=true)
    rm(path48, force=true, recursive=true)
    nothing
end


## module end
end