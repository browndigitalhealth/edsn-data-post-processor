module DataPostProcessor

include("modules/ConfigValidator.jl")
include("modules/Constants.jl")

import YAML
using .Constants

export validate_config
function validate_config(config_path::String)
    config = YAML.load_file(config_path)
    ConfigValidator.check_error_and_exit_conditions(config)
    ConfigValidator.check_warn_conditions(config)
end

export validate_input_files
function validate_input_files(config_path::String, input_files_path::String)
    validate_config(config_path)
    config = YAML.load_file(config_path)
    ConfigValidator.check_csv_files(config, input_files_path)
end

end # module
