# Exponential sine sweep
function exp_sine_sweep(f_start::Float64, f_stop::Float64, time::Float64, sample_rate::Float64)
    
    sps = round(time * sample_rate)
    const samples = convert(Int64, sps)

    mul = (f_stop / f_start) ^ (1.0 / sps)
    delta = 2.0 * pi * f_start / sample_rate
    play = zeros(Float64, samples)

    #calculate the phase increment gain
    #closed form --- [i.play[pauseSps] .. i.play[pauseSps + chirpSps - 1]]
    
	phi = 0.0
	for k = 1:samples
		play[k] = phi
		phi = sum_kbn([phi, delta])
		delta = delta * mul
    end
    
    #the exp sine sweeping time could be non-integer revolutions of 2 * pi for phase phi.
    #Thus we find the remaining and cut them evenly from each sweeping samples as a constant bias.
	delta = -mod(play[samples], 2.0 * pi)
	delta = delta / (sps - 1.0);
	phi = 0.0
	for k = 1:samples
		play[k] = sin(play[k] + phi);
	    phi = sum_kbn([phi, delta]);
    end
    play
end


function fft_fixedsize(x, n)
    fft( [x; zeros(typeof(x[1]), n - length(x))] )
end

function ifft_fixedsize(x, n)
    ifft( [x; zeros(typeof(x[1]), n - length(x))] )
end


# Decode Impulse Response
function decode_impulse(ess::Array{Float64}, f_start::Float64, f_stop::Float64, ess_response::Array{Float64})
    
    #reverse ess signal and make gain compensation
    slope = 20.0 * log10(0.5)
    attn = slope * log2(f_stop/f_start) / (length(ess) - 1)
    gain = 0.0

    essinv = flipdim(ess,1)
    for i = 1:length(essinv)
        essinv[i] = essinv[i] * (10.0 ^ (gain/20+1))
        gain += attn
    end
    #temp = abs.(fft(ess)) .* abs.(fft(essinv))
    #must be flat, i.e. spectrum of white


    #calculate impulse response
    #convolve with the gain-compensated inverse filter
    nfft = nextpow2( length(ess) + length(ess_response) - 1 )
    essinvfft = fft_fixedsize( essinv, nfft )
                
    impulse = real(ifft(fft_fixedsize(ess,nfft) .* essinvfft))/nfft
    response = real(ifft(fft_fixedsize(ess_response,nfft) .* essinvfft))/nfft    
    
    #response[length(ess):end]
    impulse[length(ess):end]
end