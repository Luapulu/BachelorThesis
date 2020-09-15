module MaGeAnalysis

using Distributed, JLD2, MJDSigGen, Logging
using MJDSigGen:
    Struct_MJD_Siggen_Setup, signal_calc_init, fieldgen, outside_detector

import Base
import MJDSigGen: get_signal!

# Fundamental structs
export MaGeHit, MaGeEvent

# Detector setup
export init_detector_setup

# Working with files
export getdelimpaths, readevent, eachevent, getjldpaths, eventstojld, getevents, filemap, save

# Signals
export get_signal, get_signal!, Signals, get_signals, get_signals!

# Analysing data
export energy


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
    hits::Vector{MaGeHit}
    eventnum::Int
    hitcount::Int
    primarycount::Int
    fileindex::Int
    function MaGeEvent(hits, eventnum, hitcount, primarycount, fileindex)
        if length(hits) != hitcount
            throw(ArgumentError("hitcount $hitcount must equal number of hits $(length(hits))"))
        end
        return new(hits, eventnum, hitcount, primarycount, fileindex)
    end
end
Base.size(e::MaGeEvent) = (e.hitcount,)
Base.eltype(::Type{MaGeEvent}) = MaGeHit
Base.getindex(e::MaGeEvent, i::Int) = getindex(e.hits, i)
Base.:(==)(e1::MaGeEvent, e2::MaGeEvent) =
    e1.primarycount == e2.primarycount &&
    e1.eventnum == e2.eventnum &&
    e1.fileindex == e2.fileindex &&
    e1.hits == e2.hits
function Base.show(io::IO, e::MaGeEvent)
    print(io, "MaGeEvent(")
    print(io, "Array{", eltype(e), "}(", size(e), ")")
    print(io, ", ", e.eventnum, ", ", e.hitcount, ", ", e.primarycount, ", ", e.fileindex, ")")
end

Base.show(io::IO, m::MIME"text/plain", e::MaGeEvent) = show(io, e)
Base.hash(e::MaGeEvent) = hash((e.primarycount, e.eventnum, e.fileindex, e.hits))

include("detector.jl")
include("magefiles.jl")
include("Signals.jl")
include("analyse.jl")

end # Module
