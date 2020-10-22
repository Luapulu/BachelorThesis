using Distributed
worker_num = 16
nprocs() <= worker_num && addprocs(1 + worker_num - nprocs())

@everywhere begin
    import Pkg
    Pkg.activate(".")
    Pkg.instantiate()
end

@everywhere begin
    using MaGeSigGen, JLD
    using DelimitedFiles, Interpolations
end

signal_paths = readdir("/mnt/e15/comellato/results4Paul_hd/", join=true)

@everywhere const elect_params_GWD6022 = (
    GBP = 150e+06,
    Cd  = 3.5e-12,
    tau = 65e-06,
    Cf  = 0.65e-12,
    Rf  = 2e+07,
    Kv  = 5e+05
)

@everywhere begin
    raw = vec(readdlm("/mnt/geda00/comellato/pss/unisexMacros/noiseArrayDEP100MHz.dat"))

    # periodic boundary conditions
    push!(raw, raw[1])

    # un-normalize
    raw .*= 1592.5

    linearitp = interpolate(raw, BSpline(Linear()))
    const cryo_noise_linear = map(linearitp, 1:0.1:length(raw) - 0.1)
end

@everywhere getσE(E) = sqrt(0.244593 + 0.00211413 * E) / (2 * √(2 * log(2)))

@everywhere function getEandA(signal)
    E = maximum(signal)

    s = apply_electronics(signal; elect_params_GWD6022...)

    s .*= E / maximum(s)

    s = addnoise!(s, cryo_noise_linear)

    s = moving_average(s, 100, 5)

    return get_noisy_energy(E, getσE(E)), getA(s)
end

EsAs = pmap(signal_paths) do signal_path
    vcat(map(s -> hcat(getEandA(s)...), signals(load_signals(SignalDict, signal_path)))...)
end

savepath = joinpath(dir, "EsAs-no-group-effects.jld")
save(savepath, "EsAs", vcat(EsAs...))
