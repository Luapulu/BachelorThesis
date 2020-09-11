module MaGeAnalysis

using Distributed, JLD2, MJDSigGen

import Base

# Fundamental structs
export MaGeHit, MaGeEvent

# Working with files
export getdelimpaths, readevent, eachevent, getjldpaths, delimtojld, getfile, filemap

# Analysing data
export getcounts, getbin, calcenergy

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
Base.size(e::MaGeEvent) = (e.hitcount,)
Base.eltype(::Type{MaGeEvent}) = MaGeHit
Base.getindex(e::MaGeEvent, i::Int) = getindex(e.hits, i)
Base.:(==)(e1::MaGeEvent, e2::MaGeEvent) =
    e1.primarycount == e2.primarycount && e1.eventnum == e2.eventnum && e1.hits == e2.hits
function Base.show(io::IO, e::MaGeEvent)
    print(io, "MaGeEvent(")
    print(io, "Array{", eltype(e), "}(", size(e), ")")
    print(io, ", ", e.eventnum, ", ", e.hitcount, ", ", e.primarycount, ")")
end

Base.show(io::IO, m::MIME"text/plain", e::MaGeEvent) = show(io, e)
Base.hash(e::MaGeEvent) = hash((e.primarycount, e.eventnum, e.hits))

include("magefiles.jl")
include("analyse.jl")
include("waveforms.jl")

end # Module
