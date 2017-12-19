module QUICKANNO

import WAV
include("data.jl")


# block: minimal seconds of one block
function fragmentation(path::String, block::Float64)
    p = joinpath(tempdir(), "quickanno")
    rm(p, force=true, recursive=true)
    mkdir(p)

    fragments = Array{String}()

    files = DATA.list(path, t=".wav")
    for (i,j) in enumerate(files)
        x,sr = wavread(j)
        n = size(x,1)
        sps::Int64 = Int64(round(sr * block))

        ps = joinpath(p,"$i")
        mkdir(ps)

        q = div(n,sps) - 1
        for k = 0:q-1
            wavwrite(view(x,k*sps+1:(k+1)*sps,:), joinpath(ps,"$k.wav"), Fs=sr, nbits=32)
            push!(fragments, joinpath("$i","$k.wav"))
        end
        wavwrite(view(x,q*sps+1:n,:), joinpath(ps,"$q.wav"), Fs=sr, nbits=32)
        push!(fragments, joinpath("$i","$q.wav"))
    end
end


end