## Generating signals for events and hits ##

function get_signal!(pulse::DenseVector{Float32}, location::NTuple{3,T} where T)
    get_signal!(pulse, SETUP, location)
end

function get_signal(location::NTuple{3,T} where T)
    get_signal!(SETUP, location)
end

function get_signal!(pulse::DenseVector{Float32}, h::MaGeHit)
    if !outside_detector((h.x, h.y, h.z))
        get_signal!(pulse, (h.x, h.y, h.z))
    end
    return pulse
end

get_signal(h::MaGeHit) = get_signal((h.x, h.y, h.z))

function get_signal!(
    finpulse::DenseVector{Float32},
    event::MaGeEvent,
    pulse::DenseVector{Float32} = Vector{Float32}(undef, SETUP.ntsteps_out),
)
    for hit in event
        get_signal!(pulse, hit)
        finpulse += (hit.E .* pulse)
    end
    return finpulse
end

get_signal(e::MaGeEvent) = get_signal!(zeros(Float32, SETUP.ntsteps_out), e)

## Generating signals for multiple events ##

function get_signals!(
    sigs::Vector{Union{Missing,Vector{Float32}}},
    events::Vector{MaGeEvent};
    replace::Bool = false,
    info_every::Int = 100,
)
    for (i, e) in enumerate(events)
        if ismissing(sigs[e.fileindex]) || replace
            sigs[e.fileindex] = get_signal(e)
        end
        if i % info_every == 0
            @info "Worker $(myid()) got signals for $i out of $(length(events)) of events"
        end
    end
    @info "Worker $(myid()) got signals for all given events" signals = sigs
    return sigs
end

function get_signals(events::Vector{MaGeEvent}, l::Integer; kwargs...)
    return get_signals!(Vector{Union{Missing,Vector{Float32}}}(missing, l), events; kwargs...)
end

## Saving and loaing signals ##

save_signals(sigs::Vector{Union{Missing,Vector{Float32}}}, path::String) =
    savejld2(sigs, "signals", path)

get_signals(path::String) = loadjld2("signals", path)

## Getting signals for multiple files ##

function getsignalpath(path::String, dir::String)
    d, f = splitdir(path)
    savepath = joinpath(dir, splitext(f)[1] * "_signals" * ".jld2")
end

function get_signals(
    condition,
    eventpaths::Union{String,Vector{String}},
    savedir::String;
    kwargs...,
)
    filemap(eventpaths) do path
        events = get_events(path)
        sigs = get_signals(filter(condition, events), length(events); kwargs...)

        sigpath = getsignalpath(path, savedir)
        save_signals(sigs, sigpath)

        @info "Worker $(myid()) saved signals to $(splitdir(sigpath)[2])"
        return sigs
    end
end

function get_signals!(
    condition,
    eventpaths::Union{String,Vector{String}},
    savedir::String;
    kwargs...,
)
    filemap(eventpaths) do path
        sigpath = getsignalpath(path, savedir)
        sigs = get_signals(sigpath)
        events = get_events(path)

        get_signals!(sigs, filter(condition, events); kwargs...)
        save_signals(sigs, sigpath)

        @info "Worker $(myid()) saved signals to $(splitdir(sigpath)[2])"
        return sigs
    end
end
