include("../common/common.jl")
using YAML

const PROJECT_CONFIG = YAML.load_file("project-config.yaml")
const CO56_MAGE_CONFIG = PROJECT_CONFIG["Co-56_MaGeHits"]
const CO56_HIT_ITER = MaGeHitIter(CO56_MAGE_CONFIG["dirpath"], Regex(CO56_MAGE_CONFIG["pattern"]))
