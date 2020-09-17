module MaGeSigGen

using Distributed, JLD, MJDSigGen, Logging, MacroTools
using MJDSigGen:
    Struct_MJD_Siggen_Setup, signal_calc_init, fieldgen

import Base
import MJDSigGen: get_signal!, outside_detector
import JLD: save

# Fundamental structs
export Hit, Event

# Detector setup
export init_detector, outside_detector, fieldgen

# Event files
export save, events_to_jld, get_events

# Event processing
export energy

# Signal generation
export get_signal, get_signal!, get_signals, get_signals!

# Signal processing
export getA


include("types.jl")
include("detector.jl")
include("event-files.jl")
include("event-processing.jl")
include("get_signals.jl")
include("signal-processing.jl")

end # Module
