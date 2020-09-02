module MaGeAnalysis

using Base.Iterators: take
using Distributed, JLD, UUIDs

import Base: iterate, size, getindex, show, length, close, eltype, IteratorSize, ==
import JLD: save

# Fundamental structs
export MaGeHit, MaGeEvent

# Getting data from files
export magerootpaths, eachevent, readevent

# Analysing data
export filemap, getcounts, getbin, calcenergy

struct MaGeHit
    x::Float32
    y::Float32
    z::Float32
    E::Float32
    t::Float32
    particleid::Int32
    trackid::Int32
    trackparentid::Int32
end

struct MaGeEvent <: AbstractVector{MaGeHit}
    hits::AbstractVector{MaGeHit}
    eventnum::Int
    hitcount::Int
    primarycount::Int
    function MaGeEvent(hits, eventnum, hitcount, primarycount)
        if length(hits) != hitcount
            throw(ArgumentError("hitcount $hitcount must equal number of hits $(length(hits))"))
        end
        return new(hits, eventnum, hitcount, primarycount)
    end
end
size(e::MaGeEvent) = (e.hitcount,)
eltype(::Type{MaGeEvent}) = MaGeHit
getindex(e::MaGeEvent, i::Int) = getindex(e.hits, i)
==(e1::MaGeEvent, e2::MaGeEvent) =
    e1.primarycount == e2.primarycount && e1.eventnum == e2.eventnum && e1.hits == e2.hits
function show(io::IO, e::MaGeEvent)
    print(io, "MaGeEvent(")
    print(io, "Array{", eltype(e), "}(", size(e), ")")
    print(io, ", ", e.eventnum, ", ", e.hitcount, ", ", e.primarycount, ")")
end

include("magefiles.jl")
include("analyse.jl")

end # Module
