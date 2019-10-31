module DataPostProcessor

include("modules/ConfigValidator.jl")

import YAML

export validate_config
function validate_config(path::String)
    config = YAML.load_file(path)
    ConfigValidator.check_error_and_exit_conditions(config)
    ConfigValidator.check_warn_conditions(config)
end

end # module
