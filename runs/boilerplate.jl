import Pkg
Pkg.activate(".")
Pkg.instantiate()

using YAML, MaGeAnalysis

configpath = realpath(joinpath(dirname(pathof(MaGeAnalysis)), "..", "runs", "config.yaml"))

const CONFIG = YAML.load_file(configpath)
const CO56_DELIMITED_DIR = CONFIG["Co-56_MaGeHits"]["dirpath"]
const CO56_JLD_DIR = CONFIG["Co-56_MaGeHits"]["jldpath"]

const CO56_DELIMITED_FILES = getdelimpaths(CO56_DELIMITED_DIR)
const CO56_JLD_FILES = getjldpaths(CO56_DELIMITED_DIR)
