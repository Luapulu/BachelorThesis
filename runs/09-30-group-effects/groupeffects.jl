using MaGeSigGen, MaGe, MJDSigGen
using MJDSigGen: outside_detector

dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-23-siggen2"))

event_dir = "/mnt/e15/comellato/results4Paul/GWD6022_Co56_side50cm/DM"
event_paths = filter(p -> occursin(r".root.hits$", p), readdir(event_dir, join=true))
signal_paths = map(
    p -> joinpath(dir, "signals", split(splitdir(p)[end], '.')[1] * "_signals.jld"),
    event_paths
)

cd(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-30-group-effects"))

const setup = MJDSigGen.signal_calc_init("GWD6022_01ns.config")

elect_params_GWD6022 = (
    GBP = 150e+06,
    Cd  = 3.5e-12,
    tau = 65e-06,
    Cf  = 0.65e-12,
    Rf  = 2e+07,
    Kv  = 5e+05
)

getσE(E) = sqrt(0.244593 + 0.00211413 * E) / (2 * √(2 * log(2)))

function getEandAweffs(event, signal, setup, elect_params, ns)
    E = energy(event)

    loc = location(first(hits(event)))
    outside_detector(setup, loc) && return get_noisy_energy(E, getσE(E)), missing

    δτ = with_group_effects!(setup, E, charge_cloud_size(E)) do stp
        getδτ(stp, loc)
    end

    s = apply_group_effects(signal, δτ, setup.step_time_out, true)
    s = apply_electronics(s; elect_params...)
    s = moving_average(s, ns, 3)

    s .*= E ./ maximum(s)

    return get_noisy_energy(E, getσE(E)), getA(s)
end

function map_events_signals(f::Function, event_path::AbstractString, signal_path::AbstractString, setup, args...)
    sgnls = load_signals(SignalDict, signal_path)
    return hcat(collect(
        (todetcoords!(event, setup); collect(f(event, sgnls[event], setup, args...)))
        for event in MaGe.loadstreaming(event_path) if !ismissing(sgnls[event])
    )...)
end

function map_events_signals(f::Function, event_paths::Vector{<:AbstractString}, signal_paths::Vector{<:AbstractString}, setup, args...)
    return hcat(map(zip(event_paths, signal_paths)) do (epath, spath)
        map_events_signals(f, epath, spath, setup, args...)
    end...)
end

@time map_events_signals(getEandAweffs, event_paths[1:5], signal_paths[1:5], setup, elect_params_GWD6022, 100)
