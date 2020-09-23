getA(signal) = maximum(diff(signal))

function drift_time(signal, lowthr, highthr; step_time_out=setup().step_time_out)
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

drift_time(signal; step_time_out=setup().step_time_out) = length(signal) * step_time_out

"""
    ch_cloud_size(energy)

returns charge cloud size as maximum of A + B × energy and 0.01.

Parameters A and B were obtained from MC of BSI inv-coax (evolution of R90, rescaled for FWHM)
"""
charge_cloud_size(energy) = max(-0.03499440089585633 + 0.0003359462486002238 * energy, 0.01)

function getδτ(firstloc)
    get_signal(firstloc)
    return setup().final_charge_size / setup().final_vel
end

function gausswindow(σ, nσ; step_time_out=setup().step_time_out)
    # number of time steps to 1σ
    stepσ = σ / step_time_out

    # Number of samples so that nσ of stepσ reaches edge of window
    n = round(Int, 2 * nσ * stepσ)

    return gaussian(n, 0.5 / nσ)
end

function pad_signal!(padvec, signal, wlen)
    sl = length(signal)

    # Padding only needed at end, since the beginning of the signal is ≈ 0
    padvec[1:sl] .= signal
    padvec[sl+1:wlen+sl-1] .= signal[end]

    return padvec[1:sl+wlen-1]
end

function apply_group_effects(
    signal,
    δτ::Real,
    padding::Bool,
    padvec = (padding ? similar(signal, 2 * length(signal)) : similar(signal, 0)),
)
    # because δτ is FWHM
    σ = δτ / (2 * √(2 * log(2)))

    # gaussian window with 4σ to each edge
    w = gausswindow(σ, 4)

    if padding
        sl = length(signal)
        wl = length(w)
        return conv(pad_signal!(padvec, signal, wl), w)[1:sl + wl - 1]
    else
        return conv(signal, w)
    end
end

function apply_electronics(signal) end

function set_noisy_energy!(signal, E, σE)
    signal .*= rand(Normal(E, σE)) / signal[end]
    return signal
end
