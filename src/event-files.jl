## Parsing .root.hits files ##

function parse_meta(stream::IO)
    eventnum = tryparse(Int32, readuntil(stream, ' '))
    hitcount = tryparse(Int32, readuntil(stream, ' '))
    primarycount = tryparse(Int32, readuntil(stream, '\n'))
    return eventnum, hitcount, primarycount
end

function parse_hit(stream::IO)
    x = tryparse(Float64, readuntil(stream, ' '))
    y = tryparse(Float64, readuntil(stream, ' '))
    z = tryparse(Float64, readuntil(stream, ' '))
    E = tryparse(Float64, readuntil(stream, ' '))
    t = tryparse(Float64, readuntil(stream, ' '))
    particleid = tryparse(Int64, readuntil(stream, ' '))
    trackid = tryparse(Int64, readuntil(stream, ' '))
    trackparentid = tryparse(Int64, readuntil(stream, ' '))

    skip(stream, 9)

    x, y, z = to_detector_coords(x, y, z)

    return HitTuple((x, y, z, E, t, particleid, trackid, trackparentid))
end

function parse_hits!(hitvec::AbstractVector, stream::IO, hitcount::Integer)
    length(hitvec) < hitcount && resize!(hitvec, hitcount)
    for i = 1:hitcount
        hitvec[i] = parse_hit(ranges, readline(stream))
    end
    return hitvec
end


## RootHitEvents ##

struct RootHitEvents{E} <: EventCollection{E}
    stream::IO
end
RootHitEvents{E}(f::AbstractString) where E = RootHitEvents{E}(Base.open(f, lock = false))

function Base.iterate(
    es::RootHitEvents{E},
    hitvec = Vector{H}(undef, 500),
) where {E<:AbstractEvent{H}} where {H}
    eof(es.stream) && return (close(es.stream); nothing)
    eventnum, hitcount, primarycount = parse_meta(es.stream)
    parse_hits!(hitvec, es.stream, hitcount)
    return E(hitvec, eventnum, hitcount, primarycount), hitvec
end

## JLDEvents ##

struct JLDEvents{E} <: EventCollection{E}
    events::Vector{E}
end

get_events(JLDEvents, path::AbstractString) = load(path, "events")
save(path::AbstractString, es::EventCollection) = save(path, "events", collect(EventTuple, es))
get_events(::Type{EC}, path::AbstractString) where {EC<:EventCollection} = EC(path)

## get_events ##

is_root_hit_file(path::AbstractString) = occursin(r"root.hits$", path)

const EVENT_FILES = [
    (is_root_hit_file, RootHitEvents)
]

function get_events(path::AbstractString)
    for (test, T) in FILE_QUERIES
        test(path) && return get_events(T, path)
    end
    error("no registered file type for $path")
    nothing
end
