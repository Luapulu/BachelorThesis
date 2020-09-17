## Parsing .root.hits files ##

function get_parse_ranges!(line::AbstractString, ranges = Vector{UnitRange{Int32}}(undef, 8))
    start = 1
    for i = 1:8
        r = findnext(" ", line, start)
        ending, next = prevind(line, first(r)), nextind(line, last(r))
        ranges[i] = start:ending
        start = next
    end
    return ranges
end

ishitline(line::AbstractString) = length(line) > 20 && line[end-8:end] == " physiDet"

function parsehit(line::AbstractString, ranges = Vector{UnitRange{Int32}}(undef, 8))
    !ishitline(line) && error("cannot parse \"$line\" as hit")
    ranges = get_parse_ranges!(line, ranges)
    x = parse(Float32, line[ranges[3]])
    y = parse(Float32, line[ranges[1]])
    z = parse(Float32, line[ranges[2]])
    E = parse(Float32, line[ranges[4]])
    t = parse(Float32, line[ranges[5]])
    particleid = parse(Int32, line[ranges[6]])
    trackid = parse(Int32, line[ranges[7]])
    trackparentid = parse(Int32, line[ranges[8]])

    x, y, z = to_detector_coords(x, y, z)

    return x, y, z, E, t, particleid, trackid, trackparentid
end

function parsemeta(line::AbstractString)
    intparse(str) = tryparse(Int, str)
    return Tuple(map(intparse, split(line, " ", limit=3)))
end

function parse_event(stream::IO, fileindex::Int)
    metaline = readline(stream)
    eventnum, hitcount, primarycount = parsemeta(metaline)

    if isnothing(eventnum) || isnothing(eventnum) || isnothing(eventnum)
        error("cannot parse the following as meta line: \"$metaline\"")
    end

    hitvec = Vector{Hit}(undef, hitcount)
    for i in 1:hitcount
        hitvec[i] = parsehit(readline(stream))
    end

    return hitvec[1:hitcount], eventnum, hitcount, primarycount, fileindex
end


## Event Collections ##

abstract type EventCollection{E<:AbstractEvent} end

Base.IteratorSize(::Type{EventCollection}) = Base.SizeUnknown()

Base.IteratorEltype(::Type{EventCollection}) = Base.HasEltype()
Base.eltype(::Type{EventCollection{E}}) where {E} = E

Base.iterate(es::EventCollection, state) = Base.iterate(get_events(es), state)
Base.iterate(es::EventCollection) = Base.iterate(get_events(es))

save(path::AbstractString, es::EventCollection) = save(path, "events", es)


## RootHitEvents ##

struct RootHitEvents{E} <: EventCollection{E}
    stream::IO
end
RootHitEvents(f::AbstractString) = RootHitEvents(Base.open(f, lock=false))

function Base.iterate(es::RootHitEvents, (1, )
    eof(es.stream) && return (close(es.stream); nothing)
    return (parse_event(es.stream, i), i + 1)
end

save(path::AbstractString, es::RootHitEvents) = save(path, "events", es)
get_events(path::AbstractString) = load(path, "events")
