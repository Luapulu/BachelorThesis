module MaGeSigGen

using Distributed, JLD, MJDSigGen, Logging, MacroTools
using MJDSigGen:
    Struct_MJD_Siggen_Setup, signal_calc_init, fieldgen

import Base
import MJDSigGen: get_signal!, outside_detector
import JLD: save

# Detector setup
export init_detector, outside_detector, fieldgen

# Hits
export Hit, location, energy, time, particleid, trackid, trackparentid

# Events
export Event, hits, hitcount, eventnum, primarycount

# Event files
export load_events

# Signal generation
export get_signal, get_signal!, get_signals, get_signals!

# Signal processing
export getA


include("detector.jl")
include("types.jl")
include("event-files.jl")
include("get_signals.jl")
# include("signal-processing.jl")

end # Module
