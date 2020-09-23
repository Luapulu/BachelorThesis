## get_signal ##

function get_signal!(pulse::DenseVector{Float32}, location::NTuple{3})
    return get_signal!(pulse, setup(), location)
end

get_signal(location::NTuple{3}) = get_signal!(setup(), location)

function get_signal!(final_pulse::DenseVector{Float32}, working_pulse::DenseVector{Float32}, event)
    for h in hits(event)
        if !outside_detector(location(h))
            get_signal!(working_pulse, location(h))
            final_pulse .+= (energy(h) .* working_pulse)
        end
    end
    return final_pulse
end

function get_signal(event, ntsteps_out=setup().ntsteps_out)
    get_signal!(zeros(Float32, ntsteps_out), Vector{Float32}(undef, ntsteps_out), event)
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

function save(path::AbstractString, S::SignalDict, ntsteps_out=setup().ntsteps_out)
    mat = Matrix{Float32}(undef, ntsteps_out, length(S))
    for (i, s) in enumerate(signals(S))
        mat[:, i] .= s
    end
    save(path, "signals", (collect(keys(S)), mat))
end

function load_signals(S::Type{SignalDict}, path::AbstractString)
    ks, mat = load(path, "signals")
    return S(Dict(zip(ks, eachcol(mat))))
end


## get_signals ##

function get_signals!(
    signals,
    events,
    working_pulse::DenseVector{Float32} = Vector{Float32}(undef,  setup().ntsteps_out),
    ntsteps_out::Integer = setup().ntsteps_out;
    replace::Bool = false,
)
    siggen_count = 0
    for (i, e) in enumerate(events)
        if ismissing(signals[e])
            signals[e] = get_signal!(zeros(Float32, ntsteps_out), working_pulse, e)
            siggen_count += 1
        elseif replace
            signals[e] .= 0
            get_signal!(signals[e], working_pulse, e)
            siggen_count += 1
        end
    end
    @info "Worker $(myid()) got $(length(events)) events and generated $(siggen_count) signals"
    return signals
end

function get_signals(S::Type{<:SignalCollection}, events)
    return get_signals!(S(), events)
end
