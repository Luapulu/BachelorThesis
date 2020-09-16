module MaGeSigGen

using Distributed, JLD, MJDSigGen, Logging, MacroTools
using MJDSigGen:
    Struct_MJD_Siggen_Setup, signal_calc_init, fieldgen

import Base
import MJDSigGen: get_signal!, outside_detector

# Fundamental structs
export MaGeHit, MaGeEvent

# Detector setup
export init_detector, outside_detector, fieldgen

# Event processing
export eachevent, save_events, get_events, energy

# Signal generation
export get_signal, get_signal!, get_signals, get_signals!, save_signals

# Signal processing
export getA


include("utils.jl")

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

struct MaGeEvent <: DenseVector{MaGeHit}
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
@forward MaGeEvent.hits Base.eltype, Base.getindex
Base.size(e::MaGeEvent) = (e.hitcount,)
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
include("files.jl")
include("event-processing.jl")
include("get_signals.jl")
include("signal-processing.jl")

end # Module
