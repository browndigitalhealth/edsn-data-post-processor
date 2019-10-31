module ConfigValidator

include("Constants.jl")
include("Utils.jl")

using .Constants

export check_error_and_exit_conditions
function check_error_and_exit_conditions(config)
    check_required_structure(config)
    if !haskey(config[KEY_GLOBAL], KEY_GLOBAL_MISSING) ||
            !isa(config[KEY_GLOBAL][KEY_GLOBAL_MISSING], AbstractString)
        error(ERROR_REQUIRED_GLOBAL)
    end
    if !haskey(config[KEY_GLOBAL], KEY_GLOBAL_STUDY_ID) ||
            !isa(config[KEY_GLOBAL][KEY_GLOBAL_STUDY_ID], AbstractString)
        error(ERROR_REQUIRED_GLOBAL)
    end
    if any(col -> has_key_with_type(col, KEY_COLUMN_NAME, AbstractString), config[KEY_COLUMNS]) ||
            any(col -> has_key_with_type(col, KEY_COLUMN_TYPE, AbstractString), config[KEY_COLUMNS])
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
    col_name_duplicate_config = Utils.find_first_duplicate(map(col -> col[KEY_COLUMN_NAME], config[KEY_COLUMNS]))
    if !isnothing(col_name_duplicate_config)
        error("Duplicate configs found for column `$(col_name_duplicate_config)`")
    end
end

export check_warn_conditions
function check_warn_conditions(config)
    check_required_structure(config)
    warn_unknown_props(config[KEY_GLOBAL], [KEY_GLOBAL_MISSING, KEY_GLOBAL_STUDY_ID])
    known_col_props = [KEY_COLUMN_NAME, KEY_COLUMN_TYPE, KEY_COLUMN_REPLACE_MISSING]
    foreach(config[KEY_COLUMNS]) do col
        warn_unknown_props(col, known_col_props, prefix = "Config for column `$(col[KEY_COLUMN_NAME])`")
    end
end

export check_csv_files
function check_csv_files(config, input_files_path::AbstractString)
    if !isdir(input_files_path)
        error(ERROR_INPUT_FOLDER)
    end
    study_id_name = config[KEY_GLOBAL][KEY_GLOBAL_STUDY_ID]
    all_csv_col_names = []
    config_col_names = Set(map(col -> col[KEY_COLUMN_NAME], config[KEY_COLUMNS]))
    cd(input_files_path) do
        foreach(filter(file -> endswith(file, ".csv"), readdir())) do file_name
            col_names = split(readline(file_name), ",") # assume first line is CSV header
            if study_id_name ∉ col_names
                error("File `$(file_name)` is missing subject ID `$(study_id_name)`")
            end
            append!(all_csv_col_names, col_names)
        end
        csv_col_names = filter(col -> col !=  study_id_name, all_csv_col_names)
        dup_col_name = Utils.find_first_duplicate(csv_col_names)
        if !isnothing(dup_col_name)
            error("Multiple data columns in the input files found for `$(dup_col_name)`")
        end
        foreach(setdiff(csv_col_names, config_col_names)) do col_name
            @warn "Found data for column `$(col_name)` but could not find config. Ignoring..."
        end
        foreach(setdiff(config_col_names, csv_col_names)) do col_name
            @warn "Found config for column `$(col_name)` but could not find data. Ignoring..."
        end
    end
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
    if !isa(config[KEY_COLUMNS], AbstractArray)
        error(ERROR_STRUCTURE_COLUMNS)
    end
end

function has_key_with_type(col_config::AbstractDict, col_key::AbstractString, type::Type)
    !haskey(col_config, col_key) || !isa(col_config[col_key], type)
end

function find_name_with_invalid_require_missing(cols::AbstractArray)
    index = findfirst(cols) do col_config
        haskey(col_config, KEY_COLUMN_REPLACE_MISSING) && !isa(col_config[KEY_COLUMN_REPLACE_MISSING], AbstractArray)
    end
    isnothing(index) ? nothing : cols[index][KEY_COLUMN_NAME]
end

function find_name_with_invalid_type(cols::AbstractArray)
    index = findfirst(cols) do col_config
        col_config[KEY_COLUMN_TYPE] != VALUE_COLUMN_TYPE_STRING &&
            col_config[KEY_COLUMN_TYPE] != VALUE_COLUMN_TYPE_NUMBER
    end
    isnothing(index) ? nothing : cols[index][KEY_COLUMN_NAME]
end

function warn_unknown_props(config::AbstractDict, known_props::AbstractArray; prefix = "Config")
    foreach(keys(config)) do prop_name
        if prop_name ∉ known_props
            @warn "$(prefix) has unknown key `$(prop_name)`"
        end
    end
end

end # module
