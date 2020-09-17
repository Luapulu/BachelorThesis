## Generating signals for events and hits ##

function get_signal!(pulse::DenseVector{Float32}, location::NTuple{3,T} where T)
    get_signal!(pulse, SETUP, location)
end

get_signal(location::NTuple{3,T} where T) = get_signal!(SETUP, location)

function get_signal!(pulse::DenseVector{Float32}, h::Hit)
    if !outside_detector((h.x, h.y, h.z))
        get_signal!(pulse, (h.x, h.y, h.z))
    end
    return pulse
end

get_signal(h::Hit) = get_signal((h.x, h.y, h.z))

function get_signal!(
    final_pulse::DenseVector{Float32},
    working_pulse::DenseVector{Float32},
    event::Event,
)
    for hit in event
        get_signal!(working_pulse, hit)
        final_pulse .+= (hit.E .* working_pulse)
    end
    return final_pulse
end

function get_signal(e::Event, ntsteps_out=SETUP.ntsteps_out)
    get_signal!(zeros(Float32, ntsteps_out), Vector{Float32}(undef, ntsteps_out), e)
end

## Generating signals for multiple events ##

function get_signals!(
    signals::Vector{Union{Missing,Vector{Float32}}},
    events::AbstractVector{Event},
    ntsteps_out::Integer = SETUP.ntsteps_out,
    working_pulse::DenseVector{Float32} = Vector{Float32}(undef, ntsteps_out);
    replace::Bool = false,
)
    siggen_count = 0
    for (i, e) in enumerate(events)
        if ismissing(signals[e.fileindex]) || replace
            signals[e.fileindex] = get_signal!(zeros(Float32, ntsteps_out), working_pulse, e)
            siggen_count += 1
        end
    end
    @info "Worker $(myid()) got $(length(events)) of $(length(signals)) events and generated $(siggen_count) signals"
    return signals
end

function get_signals(events::Vector{Event}, l::Integer)
    signals = Vector{Union{Missing,Vector{Float32}}}(missing, l)
    return get_signals!(signals, events)
end

save(path::AbstractString, signals::Vector{Union{Missing,Vector{Float32}}}) =
    save(path, "signals", signals)

get_signals(path::AbstractString) = load(path, "signals")
