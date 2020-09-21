function parse_meta(stream::IO)
    eventnum = Parsers.parse(Int64, readuntil(stream, ' '))
    hitcount = Parsers.parse(Int64, readuntil(stream, ' '))
    primarycount = Parsers.parse(Int64, readuntil(stream, '\n'))
    return eventnum, hitcount, primarycount
end

function parse_hit(stream::IO)
    x = Parsers.parse(Float64, readuntil(stream, ' '))
    y = Parsers.parse(Float64, readuntil(stream, ' '))
    z = Parsers.parse(Float64, readuntil(stream, ' '))
    E = Parsers.parse(Float64, readuntil(stream, ' '))
    t = Parsers.parse(Float64, readuntil(stream, ' '))
    particleid = Parsers.parse(Int64, readuntil(stream, ' '))
    trackid = Parsers.parse(Int64, readuntil(stream, ' '))
    trackparentid = Parsers.parse(Int64, readuntil(stream, ' '))

    skip(stream, 9)

    x, y, z = to_detector_coords(x, y, z)

    return x, y, z, E, t, particleid, trackid, trackparentid
end

struct RootHitIter <: AbstractHitIter
    stream::IO
    hitcount::Integer
end

Base.IteratorSize(::Type{RootHitIter}) = Base.HasLength()
Base.length(itr::RootHitIter) = itr.hitcount

Base.IteratorEltype(::Type{RootHitIter}) = Base.HasEltype()
Base.eltype(::Type{RootHitIter}) = Tuple{Float64,Float64,Float64,Float64,Float64,Int64,Int64,Int64}

function Base.iterate(itr::RootHitIter, i = 0)
    i == itr.hitcount && return nothing
    return parse_hit(itr.stream), i + 1
end

struct RootHitReader
    stream::IO
end
RootHitReader(f::AbstractString) = RootHitReader(open(f, lock=false))

Base.IteratorSize(::Type{RootHitReader}) = Base.SizeUnknown()

const RootHitReaderElType = Tuple{Int64,Int64,Int64,RootHitIter}
Base.IteratorEltype(::Type{RootHitReader}) = Base.HasEltype()
Base.eltype(::Type{RootHitReader}) = RootHitReaderElType

function Base.iterate(reader::RootHitReader, state = nothing)
    eof(reader.stream) && return (close(reader.stream); nothing)
    enum, hitcnt, primcnt = parse_meta(reader.stream)
    return (enum, hitcnt, primcnt, RootHitIter(reader.stream, hitcnt)), nothing
end

eventnum(e::RootHitReaderElType) = e[1]
hitcount(e::RootHitReaderElType) = e[2]
primarycount(e::RootHitReaderElType) = e[3]
hits(e::RootHitReaderElType) = e[4]


## load_events ##

is_root_hit_file(path::AbstractString) = occursin(r"root.hits$", path)

function event_reader(path::AbstractString)
    if is_root_hit_file(path)
        return RootHitReader(path)
    end
    error("cannot read events from $path")
end

function load_events(E::Type{<:AbstractEvent}, path::AbstractString)
    return (E(e) for e in event_reader(path))
end
