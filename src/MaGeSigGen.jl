module MaGeSigGen

using MaGe, Distributed, JLD, Logging, DSP
using MJDSigGen: Struct_MJD_Siggen_Setup, outside_detector
using Distributions: Normal

import MJDSigGen: get_signal!
import Base
import JLD: save

# Detector setup
export with_group_effects!, todetcoords, todetcoords!

# Signal generation
export SignalDict, signals, get_signal, get_signal!, get_signals, get_signals!, save, load_signals

# Signal processing
export getA, drift_time, charge_cloud_size, getδτ, apply_group_effects, set_noisy_energy!,
    moving_average, moving_average!, addnoise!, appendrawAoEhist!, apply_electronics


include("setup.jl")
include("get_signals.jl")
include("signal-processing.jl")
include("analysis.jl")

end # Module
