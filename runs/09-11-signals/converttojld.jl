using Distributed
nworkers() < 12 && addprocs(13 - nworkers())

@everywhere import Pkg
@everywhere Pkg.activate(".")
@everywhere using MaGeSigGen

dir = realpath(joinpath(dirname(pathof(MaGeSigGen)), "..", "runs", "09-11-signals"))

configpath = realpath(joinpath(dir, "GWD6022_01ns.config"))
@everywhere init_detector($configpath)

event_dir = "/mnt/e15/comellato/results4Paul/GWD6022_Co56_side50cm/DM"

event_paths = filter(p -> occursin(r".root.hits$", p), readdir(event_dir, join=true))

@distributed for path in event_paths
    save_path = joinpath(dir, "events", split(splitdir(path)[end], ".", limit=2)[1] * ".jld2")
    save_events(MaGeEvent[e for e in eachevent(path)], save_path)
    @info "Converted $path"
    nothing
end
