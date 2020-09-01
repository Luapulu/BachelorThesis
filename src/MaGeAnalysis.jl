module MaGeAnalysis

using Base.Iterators: take
using Distributed

import Base: iterate
import Base: size, getindex, show, length

# Fundamental structs
export MaGeHit, MaGeEvent

# dealing with files
export MaGeFile, getmagepaths, getevents

# Analysing data
export filemap, calcenergy, getcounts, getbin

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
size(E::MaGeEvent) = (E.hitcount,)
getindex(E::MaGeEvent, i::Int) = getindex(E.hits, i)
show(io::IO, E::MaGeEvent) = dump(E, maxdepth = 1)

include("magefiles.jl")
include("analyse.jl")

"""
# convert to detector coordinates [mm]
xtal_length = 1
x = 10(x + 200)
y = 10y
z = -10z + 0.5xtal_length

"""

end # Module
