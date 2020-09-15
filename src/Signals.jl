function get_signal!(pulse::Vector{Float32}, h::MaGeHit, setup::Struct_MJD_Siggen_Setup=SETUP)
    if !outside_detector(setup, (h.x, h.y, h.z))
        get_signal!(pulse, setup, (h.x, h.y, h.z))
    end
    return pulse
end

function get_signal(h::MaGeHit, setup::Struct_MJD_Siggen_Setup=SETUP)
    pulse = Vector{Float32}(undef, setup.ntsteps_out)
    if !outside_detector(setup, (h.x, h.y, h.z))
        get_signal!(pulse, setup, (h.x, h.y, h.z))
        return pulse
    else
        return nothing
    end
end

function get_signal!(
    finpulse::Vector{Float32},
    event::MaGeEvent,
    setup::Struct_MJD_Siggen_Setup=SETUP,
    pulse::Vector{Float32} = Vector{Float32}(undef, setup.ntsteps_out)
)
    for hit in event
        get_signal!(pulse, hit, setup)
        finpulse += (hit.E .* pulse)
    end
    return finpulse
end

function get_signal(e::MaGeEvent, setup::Struct_MJD_Siggen_Setup=SETUP)
    return get_signal!(zeros(Float32, setup.ntsteps_out), e, setup)
end

struct Signals <: AbstractVector{Union{Missing, Vector{Float32}}}
    setup::Struct_MJD_Siggen_Setup
    vec::Vector{Union{Missing, Vector{Float32}}}
end

Signals(l::Integer, setup::Struct_MJD_Siggen_Setup=SETUP) =
    Signals(setup, Vector{Union{Missing, Vector{Float32}}}(missing, l))

function Signals(name::String, path::String, setup::Struct_MJD_Siggen_Setup=SETUP)
    open(JLD2File(path)) do f
        return Signals(setup, f[name])
    end
end

Base.eltype(::Type{Signals}) = Union{Missing, Vector{Float32}}
Base.length(sigs::Signals) = length(sigs.vec)
Base.size(sigs::Signals) = size(sigs.vec)
Base.size(sigs::Signals, n::Integer) = size(sigs.vec, n)
Base.ndims(sigs::Signals) = ndims(sigs.vec)
Base.axes(sigs::Signals) = axes(sigs.vec)
Base.axes(sigs::Signals, n::Integer) = axes(sigs.vec, n)
Base.eachindex(sigs::Signals) = eachindex(sigs.vec)
Base.stride(sigs::Signals, n::Integer) = strides(sigs.vec)
Base.strides(sigs::Signals) = strides(sigs.vec, n)
Base.view(sigs::Signals, i::Integer) = view(sigs.vec, i)

Base.getindex(sigs::Signals, i::Integer) = getindex(sigs.vec, i)
Base.setindex!(sigs::Signals, s::Missing, i::Integer) = setindex!(sigs.vec, s, i)
Base.setindex!(sigs::Signals, s::Vector{Float32}, i::Integer) = setindex!(sigs.vec, s, i)

function get_signals!(
    sigs::Signals,
    events::Vector{MaGeEvent};
    replace::Bool = false,
)
    for (i, e) in enumerate(events)
        if ismissing(sigs[e.fileindex]) || replace
            sigs[e.fileindex] = get_signal(e, sigs.setup)
            @debug "Got signal for event $i of $(length(events))" event=e signal=sigs[e.fileindex]
        end
        if i % 20 == 0
            @info "Worker $(myid()) got signals for $i out of $(length(events)) of events"
        end
    end
    return sigs
end

function get_signals(
    events::Vector{MaGeEvent},
    l::Integer;
    setup::Struct_MJD_Siggen_Setup=SETUP,
    replace::Bool = false,
)
    return get_signals!(Signals(l, setup), events, replace=replace)
end

save(sigs::Signals, name::String, path::String) = save(sigs.vec, name, path)
