using Distributed
worker_num = 16
nprocs() <= worker_num && addprocs(1 + worker_num - nprocs())

@everywhere begin
    import Pkg
    Pkg.activate(".")
    Pkg.instantiate()
end

@everywhere begin
    using MaGeSigGen, MaGe, MJDSigGen, JLD
    using MJDSigGen: outside_detector
    using DelimitedFiles, Interpolations
end

signaldir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-23-siggen2", "signals"))

event_dir = "/mnt/e15/comellato/results4Paul/GWD6022_Co56_side50cm/DM"
event_paths = filter(p -> occursin(r".root.hits$", p), readdir(event_dir, join=true))
signal_paths = map(
    p -> joinpath(signaldir, split(splitdir(p)[end], '.')[1] * "_signals.jld"),
    event_paths
)

@everywhere begin
    const dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-30-group-effects"))
    cd(dir)
    const setup = MJDSigGen.signal_calc_init("GWD6022_01ns.config")
end

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

@everywhere function getEandAweffs(event, signal, setup)
    E = energy(event)

    loc = location(first(hits(event)))
    outside_detector(setup, loc) && return get_noisy_energy(E, getσE(E)), missing

    δτ = with_group_effects!(setup, E, charge_cloud_size(E)) do stp
        getδτ(stp, loc)
    end

    s = apply_group_effects(signal, δτ, setup.step_time_out, true)
    s = apply_electronics(s; elect_params_GWD6022...)
    s = addnoise!(s, cryo_noise_linear)
    s = moving_average(s, 100, 5)

    s .*= E ./ maximum(s)

    return get_noisy_energy(E, getσE(E)), getA(s)
end

@everywhere function map_events_signals(f::Function, event_path::AbstractString, signal_path::AbstractString, setup, args...)
    sgnls = load_signals(SignalDict, signal_path)
    return hcat(collect(
        (todetcoords!(event, setup); collect(f(event, sgnls[event], setup, args...)))
        for event in MaGe.loadstreaming(event_path) if !ismissing(sgnls[event])
    )...)
end

EsAs = pmap(zip(event_paths, signal_paths)) do (epath, spath)
    return map_events_signals(getEandAweffs, epath, spath, setup)
end

savepath = joinpath(dir, "EsAs5x100ns.jld")
save(savepath, "EsAs", hcat(EsAs...))
