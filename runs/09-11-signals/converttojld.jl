using Distributed
nworkers() < 12 && addprocs(13 - nworkers())

@everywhere import Pkg
@everywhere Pkg.activate(".")
@everywhere using MaGeSigGen

dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-11-signals"))

configpath = realpath(joinpath(dir, "GWD6022_01ns.config"))
@everywhere init_detector($configpath)

event_dir = "/mnt/e15/comellato/results4Paul/GWD6022_Co56_side50cm/DM"

@distributed for path in readdir(event_dir, join=true)
    if occursin(r".root.hits$", path)
        save_path = joinpath(dir, "events", split(splitdir(path)[end], ".", limit=2)[1] * ".jld2")
        save_events(MaGeEvent[e for e in eachevent(eventpath)], save_path)
        @info "Converted $path"
    end
    nothing
end
