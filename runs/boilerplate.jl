import Pkg
Pkg.activate(".")
Pkg.instantiate()

using YAML, MaGeAnalysis

const CONFIG = YAML.load_file("config.yaml")
const CO56_DELIMITED_DIR = CONFIG["Co-56_MaGeHits"]["dirpath"]
const CO56_JLD_DIR = CONFIG["Co-56_MaGeHits"]["jldpath"]

const CO56_DELIMITED_FILES = magerootpaths(CO56_DELIMITED_DIR)
const CO56_JLD_FILES = magejldpaths(CO56_DELIMITED_DIR)
