getA(signal) = maximum(diff(signal))

function drift_time(signal, lowthr, highthr, step_time_out)
    lowthr > highthr && throw(ArgumentError("lowthr must be <= highthr"))

    minidx = 1
    while minidx <= length(signal) && signal[minidx] < lowthr
        minidx += 1
    end

    maxidx = minidx
    while maxidx <= length(signal) && signal[maxidx] < highthr
        maxidx += 1
    end

    return (maxidx - minidx) * step_time_out
end

drift_time(signal, step_time_out) = length(signal) * step_time_out

"""
    ch_cloud_size(energy)

returns charge cloud size as maximum of A + B × energy and 0.01.

Parameters A and B were obtained from MC of BSI inv-coax (evolution of R90, rescaled for FWHM)
"""
charge_cloud_size(energy) = max(-0.03499440089585633 + 0.0003359462486002238 * energy, 0.01)

function getδτ(stp::SigGenSetup, firstloc)
    get_signal!(stp, firstloc)
    return stp.final_charge_size / stp.final_vel
end

function gausswindow(σ::Real, nσ::Real, step_time_out::Real)
    # number of time steps to 1σ
    stepσ = σ / step_time_out

    # Number of samples so that nσ of stepσ reaches edge of window
    n = round(Int, 2 * nσ * stepσ)

    return gaussian(n, 0.5 / nσ)
end

function pad_signal!(padvec, signal, wl)
    sl = length(signal)

    # Padding only needed at end, since the beginning of the signal is ≈ 0
    padvec[1:sl] .= signal
    padvec[sl+1:wl+sl-1] .= signal[end]

    return padvec[1:sl+wl-1]
end

function apply_group_effects(
    signal, δτ::Real, step_time_out::Real, padding::Bool,
    padvec = (padding ? similar(signal) : similar(signal, 0))
)
    # because δτ is FWHM
    σ = δτ / (2 * √(2 * log(2)))

    # gaussian window with 4σ to each edge
    w = gausswindow(σ, 4, step_time_out)

    if padding
        sl = length(signal)
        wl = length(w)

		length(padvec) < sl + wl - 1 && resize!(padvec, sl + wl - 1)

        return conv(pad_signal!(padvec, signal, wl), w)[1:sl + wl - 1]
    else
        return conv(signal, w)
    end
end

function moving_average!(out, signal, width::Integer)
	length(out) == length(signal) || error("ouptut vector must have same length as input vector")

	# offsets from middle of window to beginning and end of window
	bo = ceil(Int, width / 2)
	eo = width - bo - 1

	# Set beginning of output to the first moving mean
	out[1:bo] .= sum(signal[1:width])

	for i in bo+1:length(signal)-eo-1
		out[i] = out[i-1] - signal[i-bo] + signal[i+eo+1]
	end

	out[end-eo:end] .= out[end-eo-1]
	out ./= width
	return out
end

function moving_average!(out, signal, width::Integer, n::Integer)
	for _ in 1:floor(Int, n / 2)
		moving_average!(out, signal, width)
		moving_average!(signal, out, width)
	end

	if isodd(n)
		moving_average!(out, signal, width)
		return out
	else
		return signal
	end
end

function moving_average(signal, width::Integer)
	moving_average!(similar(signal), signal, width)
end

function moving_average(signal, width::Integer, n::Integer)
	moving_average!(similar(signal), copy(signal), width, n)
end

function apply_electronics(signal) end

function set_noisy_energy!(signal, E, σE)
    signal .*= rand(Normal(E, σE)) / signal[end]
    return signal
end
