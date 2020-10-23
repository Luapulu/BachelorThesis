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

function getδτ(stp::SigGenSetup, loc)
    get_signal!(stp, loc)
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


function apply_electronics(pulse; GBP = 150e+06, Cd = 3.5e-12, Ts = 1e-9, tau = 65e-6, Kv = 0.5e6, Cf = 0.65e-12, Rf = 2e7)
    wop = GBP / (2 * pi * Kv)
    Cmod = Cf + Cd
    wmod = 1.0 / (Rf * Cmod)
    alfa = Cmod / (Cf * GBP)

    b0 = 1.0 / alfa
    a2 = 1.0
    a1 = 1.0 / alfa + wop + wmod
    a0 = 1.0 / (tau * alfa) + wmod*wop

    # then the transfer function in the *Laplace* s-domain looks like this:
    #                       b0
    #   T(s) = ----------------------------
    #             a2 * s^2 + a1 * s + a0

    # PolynomialRatio needs z-transform paramters: s- and z-domains can be connected by
    # the bilinear transform:
    #        z - 1
    # s = K -------- , K = Ts/2  , Ts - sampling period
    #        z + 1
    #
    # we can then convert T(s) to T(z):
    #              bz2 * z^2 + bz1 * z + bz0
    #   T(z) = -------------------------------
    #              az2 * z^2 + az1 * z + az0
    #

    K = 2/Ts

    az2 = 1.0   # normalized
    az1 = (2*a0 - 2*K^2)/(K^2 + a1*K + a0)
    az0 = (K^2 - a1*K + a0)/(K^2 + a1*K + a0)

    bz2 = b0/(K^2 + a1*K + a0)
    bz1 = 2*b0/(K^2 + a1*K + a0)
    bz0 = b0/(K^2 + a1*K + a0)

    myfilter = PolynomialRatio([bz2, bz1, bz0], [az2, az1, az0])

    filtered = filt(myfilter, vcat([0], diff(pulse)))
end

get_noisy_energy(E, σE) = rand(Normal(E, σE))


function addnoise!(signal, noise, noise_index=rand(1:length(noise)))
    i = 1
    j = noise_index

    nl = length(noise)
    sl = length(signal)

    while sl - i > nl - j
        signal[i:i + nl - j] .+= noise[j:end]

        i += nl - j + 1
        j = 1
    end

    signal[i:end] .+= noise[j:j + sl - i]

    return signal
end
