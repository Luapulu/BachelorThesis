
save_signals(signals::Vector{Union{Missing,Vector{Float32}}}, path::AbstractString) =
    savejld2(signals, "signals", path)

get_signals(path::AbstractString) = loadjld2("signals", path)

getA(signal::AbstractVector{<:Real}) = maximum(diff(signal))

energy(signal::AbstractVector{<:Real}) = signal[end]
