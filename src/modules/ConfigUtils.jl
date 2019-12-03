module ConfigUtils

include("Constants.jl")
include("DataUtils.jl")
include("Utils.jl")

using .Constants

export check_error_and_exit_conditions
function check_error_and_exit_conditions(config)
    check_required_structure(config)
    check_global_props(config)
    check_columns(config)
end

export check_warn_conditions
function check_warn_conditions(config)
    check_required_structure(config)
    warn_unknown_props(config[KEY_GLOBAL], [KEY_GLOBAL_MISSING, KEY_GLOBAL_INVALID, KEY_GLOBAL_STUDY_ID])
    known_col_props = [KEY_COLUMN_NAME, KEY_COLUMN_TYPE, KEY_COLUMN_REPLACE_MISSING]
    foreach(config[KEY_COLUMNS]) do col_config
        warn_unknown_props(col_config, known_col_props, prefix = "Config for column `$(Utils.get_col_name(col_config))`")
    end
end

export check_csv_files
function check_csv_files(config, input_files_path::AbstractString)
    if !isdir(input_files_path)
        error(ERROR_INPUT_FOLDER)
    end
    id_col = Utils.get_id_col(config)
    config_col_names = keys(build_col_configs(config))
    csv_col_names = DataUtils.find_cols(input_files_path;
        allow_duplicates = true,
        exclude_id_col = id_col) do file_name, col_names
        if !(id_col in col_names)
            error("File `$(file_name)` is missing subject ID column `$(id_col)`")
        end
    end
    # exit with error if columns with same name
    dup_col_name = Utils.find_first_duplicate(csv_col_names)
    if !isnothing(dup_col_name)
        error("Multiple data columns in the input files found for `$(dup_col_name)`")
    end
    # warn (and do not process the data later) if has data but missing config
    foreach(setdiff(csv_col_names, config_col_names)) do col_name
        @warn "Found data for column `$(col_name)` but could not find config. Ignoring..."
    end
    # warn if has config but missing in data
    foreach(setdiff(config_col_names, csv_col_names)) do col_name
        @warn "Found config for column `$(col_name)` but could not find data. Ignoring..."
    end
end

export build_col_configs
# this assumes a valid config
function build_col_configs(config::AbstractDict)
    col_configs = Dict()
    for col_config in config[KEY_COLUMNS]
        col_configs[Utils.get_col_name(col_config)] = col_config
    end
    col_configs
end

# Helpers
# -------

function check_required_structure(config)
    if !isa(config, AbstractDict)
        error(ERROR_STRUCTURE_GLOBAL)
    end
    if !isa(config[KEY_GLOBAL], AbstractDict)
        error(ERROR_STRUCTURE_GLOBAL)
    end
    if !isa(config[KEY_COLUMNS], AbstractVector)
        error(ERROR_STRUCTURE_COLUMNS)
    end
end

function check_global_props(config::AbstractDict)
    if !haskey(config[KEY_GLOBAL], KEY_GLOBAL_MISSING) ||
            !isa(Utils.get_missing_token(config), AbstractString)
        error(ERROR_REQUIRED_GLOBAL)
    end
    if !haskey(config[KEY_GLOBAL], KEY_GLOBAL_INVALID) ||
            !isa(Utils.get_invalid_token(config), AbstractString)
        error(ERROR_REQUIRED_GLOBAL)
    end
    if !haskey(config[KEY_GLOBAL], KEY_GLOBAL_STUDY_ID) ||
            !isa(Utils.get_id_col(config), AbstractString)
        error(ERROR_REQUIRED_GLOBAL)
    end
end

function check_columns(config::AbstractDict)
    if any(check_col_config_props, config[KEY_COLUMNS])
        error(ERROR_REQUIRED_COLUMN)
    end
    col_name_invalid_require_missing = find_name_with_invalid_require_missing(config[KEY_COLUMNS])
    if !isnothing(col_name_invalid_require_missing)
        error("Config for column `$(col_name_invalid_require_missing)` has key `$(KEY_COLUMN_REPLACE_MISSING)` that is not an array")
    end
    col_name_invalid_type = find_name_with_invalid_type(config[KEY_COLUMNS])
    if !isnothing(col_name_invalid_type)
        error("Config for column `$(col_name_invalid_type)` has key `$(KEY_COLUMN_TYPE)` that is not either `$(VALUE_COLUMN_TYPE_STRING)` or `$(VALUE_COLUMN_TYPE_NUMBER)`")
    end
    col_name_duplicate_config = Utils.find_first_duplicate(map(Utils.get_col_name, config[KEY_COLUMNS]))
    if !isnothing(col_name_duplicate_config)
        error("Duplicate configs found for column `$(col_name_duplicate_config)`")
    end
end

function warn_unknown_props(config::AbstractDict, known_props::AbstractVector; prefix = "Config")
    foreach(keys(config)) do prop_name
        if !(prop_name in known_props)
            @warn "$(prefix) has unknown key `$(prop_name)`"
        end
    end
end

# For a single column config
# --------------------------

function check_col_config_props(col_config::AbstractDict)
    has_key_with_type(col_config, KEY_COLUMN_NAME, AbstractString) ||
        has_key_with_type(col_config, KEY_COLUMN_TYPE, AbstractString)
end

function has_key_with_type(col_config::AbstractDict, col_key::AbstractString, type::Type)
    !haskey(col_config, col_key) || !isa(col_config[col_key], type)
end

function find_name_with_invalid_require_missing(cols::AbstractVector)
    index = findfirst(cols) do col_config
        haskey(col_config, KEY_COLUMN_REPLACE_MISSING) &&
            !isa(Utils.get_col_replace_missing(col_config), AbstractVector)
    end
    isnothing(index) ? nothing : Utils.get_col_name(cols[index])
end

function find_name_with_invalid_type(cols::AbstractVector)
    index = findfirst(cols) do col_config
        Utils.get_col_type(col_config) != VALUE_COLUMN_TYPE_STRING &&
            Utils.get_col_type(col_config) != VALUE_COLUMN_TYPE_NUMBER
    end
    isnothing(index) ? nothing : Utils.get_col_name(cols[index])
end

end # module
