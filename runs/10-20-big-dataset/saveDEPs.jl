using Distributed
worker_num = 16
nprocs() <= worker_num && addprocs(1 + worker_num - nprocs())

@everywhere begin
    import Pkg
    Pkg.activate("../../")
    Pkg.instantiate()
end

@everywhere using JLD


const tier2files = filter(p -> occursin(r"tier2_", p), readdir("/mnt/e15/comellato/results4Paul_hd/main-tier2", join=true))[1:6000]
const extrafiles = filter(p -> occursin(r"tier2_", p), readdir("/mnt/e15/comellato/results4Paul_hd/extra-tier2", join=true))[1:6000]

@everywhere const dep_regions = [1577, 1988, 2180, 2232, 2251, 2429]

@everywhere function get_DEP_data(path, dep_regions, grouped)
    Apath = (grouped ? "gA" : "A")
    data = collect((Float64[], Float64[]) for _ in dep_regions)
    num = 0
    jldopen(path) do f
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
    data
end;

@everywhere function get_DEP_extra(path, dep_regions, grouped)
    Apath = (grouped ? "gA" : "A")
    data = collect((Float64[], Float64[]) for _ in dep_regions)
    num = 0
    jldopen(path) do f
        for (E::Float64, A::Union{Missing, Float64}) in zip(read(f["E"]), read(f[Apath]))
            if !ismissing(A) && !isnan(A::Float64)
                i = findfirst(r -> r - 10 <= E < r + 10, dep_regions)
                i == 2 && E > 1990 && continue
                if !isnothing(i)
                    Earr, AoEarr = data[i]
                    push!(Earr, E)
                    push!(AoEarr, (A / E))
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
group_extra = pmap(f -> get_DEP_extra(f, dep_regions, true), tier2files)

save("dep_group_full.jld", "dep_data", concatDEPs(vcat(dep_group, group_extra)))

dep_nogroup = pmap(f -> get_DEP_data(f, dep_regions, false), tier2files)
nogroup_extra = pmap(f -> get_DEP_extra(f, dep_regions, false), tier2files)

save("dep_nogroup_full.jld", "dep_data", concatDEPs(vcat(dep_nogroup, nogroup_extra)))
