function parse_meta(stream::IO)
    eventnum = parse(Int64, readuntil(stream, ' '))
    hitcount = parse(Int64, readuntil(stream, ' '))
    primarycount = parse(Int64, readuntil(stream, '\n'))
    return eventnum, hitcount, primarycount
end

function parse_hit(stream::IO)
    x = parse(Float64, readuntil(stream, ' '))
    y = parse(Float64, readuntil(stream, ' '))
    z = parse(Float64, readuntil(stream, ' '))
    E = parse(Float64, readuntil(stream, ' '))
    t = parse(Float64, readuntil(stream, ' '))
    particleid = parse(Int64, readuntil(stream, ' '))
    trackid = parse(Int64, readuntil(stream, ' '))
    trackparentid = parse(Int64, readuntil(stream, ' '))

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
RootHitReader(f::AbstractString) = RootHitReader(open(f))

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

function Event{Vector{H}}(e::RootHitReaderElType) where {H}
    Event{Vector{H}}(e[1], e[2], e[3], collect(H, e[4]))
end

## get_events ##

is_root_hit_file(path::AbstractString) = occursin(r"root.hits$", path)
