## get_signal ##

function get_signal!(
    final_pulse::DenseVector{Float32},
    working_pulse::DenseVector{Float32},
    stp::SigGenSetup,
    event::MaGe.AbstractEvent,
)
    for h in hits(event)
        if !outside_detector(stp, location(h))
            get_signal!(working_pulse, stp, location(h))
            final_pulse .+= energy(h) .* working_pulse
        end
    end
    return final_pulse
end

function get_signal(stp::SigGenSetup, event)
    return get_signal!(
        zeros(Float32, stp.ntsteps_out),
        Vector{Float32}(undef, stp.ntsteps_out),
         stp, event
    )
end


## SignalCollection ##

abstract type SignalCollection end

Base.IteratorSize(::Type{SignalCollection}) = Base.HasLength()
Base.length(S::SignalCollection) = length(signals(S))

Base.IteratorEltype(::Type{SignalCollection}) = Base.HasEltype()
Base.eltype(::Type{SignalCollection}) = AbstractVector{Float32}

Base.iterate(S::SignalCollection) = iterate(signals(S))
Base.iterate(S::SignalCollection, state) = iterate(signals(S), state)


## SignalDict ##

struct SignalDict <: SignalCollection
    signals::Dict{Int,Vector{Float32}}
end
SignalDict() = SignalDict(Dict())

Base.eltype(::Type{SignalDict}) = Vector{Float32}

Base.keys(S::SignalDict) = keys(S.signals)

Base.getindex(S::SignalDict, i::Integer) = get(S.signals, i, missing)
Base.getindex(S::SignalDict, e) = getindex(S, eventnum(e))

Base.setindex!(S::SignalDict, signal::Vector{Float32}, i::Integer) = setindex!(S.signals, signal, i)
Base.setindex!(S::SignalDict, signal::Vector{Float32}, e) = setindex!(S, signal, eventnum(e))

signals(S::SignalDict) = values(S.signals)

function save(path::AbstractString, S::SignalDict)
    mat = Matrix{Float32}(undef, length(first(S)), length(S))
    ks = Vector{Int}(undef, length(S))
    for (i, (k, s)) in enumerate(pairs(S))
        mat[:, i] .= s
        ks[i] = k
    end
    save(path, "signals", (ks, mat))
end

function load_signals(S::Type{SignalDict}, path::AbstractString)
    ks, mat = load(path, "signals")
    return S(Dict(zip(ks, eachcol(mat))))
end


## get_signals ##

function get_signals!(
    signals,
    stp::SigGenSetup,
    events;
    replace::Bool = false,
)
    siggen_count = 0
    event_count = 0
    working_pulse = Vector{Float32}(undef, stp.ntsteps_out)

    for (i, e) in enumerate(events)
        if ismissing(signals[e])
            signals[e] = get_signal!(zeros(Float32, stp.ntsteps_out), working_pulse, stp, e)
            siggen_count += 1
        elseif replace
            signals[e] .= 0
            get_signal!(signals[e], working_pulse, stp, e)
            siggen_count += 1
        end
        event_count += 1
    end
    @info "Worker $(myid()) got $(event_count) events and generated $(siggen_count) signals"
    return signals
end

function get_signals(S::Type{<:SignalCollection}, stp, events)
    return get_signals!(S(), stp, events)
end
