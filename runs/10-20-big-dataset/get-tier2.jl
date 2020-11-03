using MaGeSigGen, MaGe, MJDSigGen, JLD
using MJDSigGen: outside_detector
using DelimitedFiles, Interpolations

## Paths

event_dir = "/mnt/e15/comellato/results4Paul/GWD6022_Co56_side50cm/DM"
signal_dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-23-siggen2", "signals"))
noise_path = "/mnt/geda00/comellato/pss/unisexMacros/noiseArrayDEP100MHz.dat"

const event_paths = map(
    p -> joinpath(event_dir, p),
    filter(p -> occursin(r".root.hits$", p), readdir(event_dir))
)

const signal_paths = map(
    p -> joinpath(signal_dir, p),
    filter(p -> occursin(r"_signals.jld$", p), readdir(signal_dir))
)

const dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "10-20-big-dataset"))
cd(dir)

!isdir("tier2") && mkdir("tier2")

## Detector Setup

const setup = MJDSigGen.signal_calc_init("GWD6022_01ns.config")

## Electronics parameters

const elect_params_GWD6022 = (
    GBP = 150e+06,
    Cd  = 3.5e-12,
    tau = 65e-06,
    Cf  = 0.65e-12,
    Rf  = 2e+07,
    Kv  = 5e+05
)

## Noise

raw = vec(readdlm(noise_path))

# periodic boundary conditions
push!(raw, raw[1])

# un-normalize
raw .*= 1592.5

linearitp = interpolate(raw, BSpline(Linear()))
const cryo_noise_linear = map(linearitp, 1:0.1:length(raw) - 0.1)

## Energy Smear Setup

getσE(E) = sqrt(0.244593 + 0.00211413 * E) / (2 * √(2 * log(2)))

## Process Event

function get_tier2_with_group_effects(event, signal)
    E = energy(event)

    loc = location(first(hits(event)))
    outside_detector(setup, loc) && return missing

    δτ = with_group_effects!(setup, E, charge_cloud_size(E)) do stp
        getδτ(stp, loc)
    end

    s = apply_group_effects(signal, δτ, setup.step_time_out, true)
    s = apply_electronics(s; elect_params_GWD6022...)
    s .*= E / maximum(s)
    s = addnoise!(s, cryo_noise_linear)
    s = moving_average(s, 100, 5)

    lt = 0.5 / 100 * maximum(s)
    ht = 90  / 100 * maximum(s)

    return (
        A  = getA(s),
        RT = drift_time(s, lt, ht, setup.step_time_out)
    )
end

function get_tier2_no_group_effects(event, signal)
    E = energy(event)

    s = apply_electronics(signal; elect_params_GWD6022...)
    s .*= E / maximum(s)
    s = addnoise!(s, cryo_noise_linear)
    s = moving_average(s, 100, 5)

    lt = 0.5 / 100 * maximum(s)
    ht = 90  / 100 * maximum(s)

    return (
        A  = getA(s),
        RT = drift_time(s, lt, ht, setup.step_time_out)
    )
end

## Main function

function get_tier2(i::Integer)
    signal_path = signal_paths[i]
    event_path = event_paths[i]
    sgnls = load_signals(SignalDict, signal_path)

    evntnum = Int[]
    E   = Float64[]
    A   = Float64[]
    RT  = Float64[]
    gA  = Float64[]
    gRT = Float64[]
    x   = Float64[]
    y   = Float64[]
    z   = Float64[]
    xE  = Float64[]
    yE  = Float64[]
    zE  = Float64[]

    @info "Working on file $i"

    for event in MaGe.loadstreaming(event_path)
        signal = sgnls[event]
        ismissing(signal) && continue

        todetcoords!(event, setup)

        push!(evntnum, eventnum(event))

        push!(E, get_noisy_energy(energy(event), getσE(energy(event))))

        ng = get_tier2_no_group_effects(event, signal)
        push!(A, ng.A)
        push!(RT, ng.RT)

        wg = get_tier2_with_group_effects(event, signal)
        push!(gA, wg.A)
        push!(gRT, wg.RT)

        firsthit = first(hits(event))
        push!(x, firsthit.x)
        push!(y, firsthit.y)
        push!(z, firsthit.z)

        push!(xE, mean(h -> h.x * h.E, event))
        push!(yE, mean(h -> h.y * h.E, event))
        push!(zE, mean(h -> h.z * h.E, event))
    end

    path = "tier2/tier2_$i.jld"
    save(path,
        "evntnum", evntnum,
        "E", E,
        "A", A,
        "RT", RT,
        "gA", gA,
        "gRT", gRT,
        "x", x,
        "y", y,
        "z", z,
        "xE", xE,
        "yE", yE,
        "zE", zE
    )
    @info "saved to $path" i
    nothing
end

function get_tier2(i::Integer, j::Integer)
    for k in i:j
        get_tier2(k)
    end
end
