using Distributed
worker_num = 16
nprocs() <= worker_num && addprocs(1 + worker_num - nprocs())

@everywhere begin
    import Pkg
    Pkg.activate(".")
    Pkg.instantiate()
end

@everywhere begin
    using MaGeSigGen
    using MaGe
    using MJDSigGen: signal_calc_init
end

dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-23-siggen2"))

@everywhere const compton_regions = [
    1070, 1105, 1130, 1187, 1220, 1300, 1420, 1480,
    1550, 1600, 1700, 1790, 1900, 2000, 2140, 2300,
    2400, 2560, 2640, 2710, 2800, 2850, 2900, 2970,
    3100, 3300
]

@everywhere const dep_regions = [1577, 1988, 2180, 2232, 2251, 2429]

@everywhere function event_filter(e)
    E = energy(e)
    incmptn = any(compton_regions .- 20 .< E .< compton_regions .+ 20)
    indep = any(dep_regions .- 3 .< E .< dep_regions .+ 3)
    return incmptn || indep
end

setup_path = joinpath(dir, "GWD6022_01ns.config")
@everywhere setup = signal_calc_init($setup_path)

event_dir = "/mnt/e15/comellato/results4Paul/GWD6022_Co56_side50cm/DM"
event_paths = filter(p -> occursin(r".root.hits$", p), readdir(event_dir, join=true))

pmap(event_paths) do epath
    @info "Worker $(myid()) working on $(splitdir(epath)[end])"

    MaGe.loadstreaming(epath) do stream
        save_path = joinpath(dir, "signals", split(splitdir(epath)[end], '.')[1] * "_signals.jld")
        sgnls = load_signals(SignalDict, save_path)

        for event in stream
            if event_filter(event)
                todetcoords!(event, setup)
                sgnls[event] = get_signal(setup, event)
            end
        end

        save(save_path, sgnls)

        @info "Saved signals to $(splitdir(save_path)[end])"

        nothing
    end

    nothing
end
