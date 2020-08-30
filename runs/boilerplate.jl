include("../common/common.jl")
using YAML

const CONFIG = YAML.load_file("config.yaml")
const CO56_MAGE_CONFIG = CONFIG["Co-56_MaGeHits"]
const CO56_HIT_FILES = geteventfiles(CO56_MAGE_CONFIG["dirpath"], Regex(CO56_MAGE_CONFIG["pattern"]))
