getA(signal::AbstractVector{<:Real}) = maximum(diff(signal))

energy(signal::AbstractVector{<:Real}) = signal[end]
