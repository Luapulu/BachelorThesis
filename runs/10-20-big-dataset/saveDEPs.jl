using Distributed
worker_num = 16
nprocs() <= worker_num && addprocs(1 + worker_num - nprocs())

@everywhere begin
    import Pkg
    Pkg.activate(".")
    Pkg.instantiate()
end

@everywhere using JLD


const tier2files = filter(p -> occursin(r"tier2_", p), readdir("/mnt/e15/comellato/results4Paul_hd/main-tier2", join=true))

const dep_regions = [1577, 1988, 2180, 2232, 2251, 2429]

function get_DEP_data(paths, dep_regions, grouped)
    Apath = (grouped ? "gA" : "A")
    data = collect((Float64[], Float64[]) for _ in dep_regions)
    num = 0
    for p in paths
        jldopen(p) do f
            (num += 1) % 100 == 0 && @info p num
            for (E::Float64, A::Union{Missing, Float64}) in zip(read(f["E"]), read(f[Apath]))
                if !ismissing(A) && !isnan(A::Float64)
                    i = findfirst(r -> r - 10 <= E < r + 10, dep_regions)
                    if !isnothing(i)
                        Earr, AoEarr = data[i]
                        push!(Earr, E)
                        push!(AoEarr, (A / E))
                    end
                end
            end
        end
    end
    data
end;

function concatDEPs(data)
    out = data[1]

    for sub in data[2:end]
        for (i, (Earr, AoEarr)) in enumerate(sub)
            append!(out[i][1], Earr)
            append!(out[i][2], AoEarr)
        end
    end

    return out
end

dep_group = pmap(f -> get_DEP_data(f, dep_regions, true), tier2files)

save("dep_group_data.jld", "dep_data", concatDEPs(dep_group))

dep_nogroup = pmap(f -> get_DEP_data(f, dep_regions, false), tier2files)

save("dep_nogroup_data.jld", "dep_data", concatDEPs(dep_nogroup))
