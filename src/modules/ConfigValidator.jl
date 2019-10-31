module ConfigValidator

include("Constants.jl")

using .Constants

export check_error_and_exit_conditions
function check_error_and_exit_conditions(config)
    check_required_structure(config)
    if !haskey(config[KEY_GLOBAL], KEY_GLOBAL_MISSING) ||
            !isa(config[KEY_GLOBAL][KEY_GLOBAL_MISSING], String)
        error(ERROR_REQUIRED_GLOBAL)
    end
    if !haskey(config[KEY_GLOBAL], KEY_GLOBAL_STUDY_ID) ||
            !isa(config[KEY_GLOBAL][KEY_GLOBAL_STUDY_ID], String)
        error(ERROR_REQUIRED_GLOBAL)
    end
    if any(col -> has_key_with_type(col, KEY_COLUMN_NAME, String), config[KEY_COLUMNS]) ||
            any(col -> has_key_with_type(col, KEY_COLUMN_TYPE, String), config[KEY_COLUMNS])
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
    col_name_duplicate_config = find_name_with_duplicate_config(config[KEY_COLUMNS])
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

# Helpers
# -------

function check_required_structure(config)
    if !isa(config, Dict)
        error(ERROR_STRUCTURE_GLOBAL)
    end
    if !isa(config[KEY_GLOBAL], Dict)
        error(ERROR_STRUCTURE_GLOBAL)
    end
    if !isa(config[KEY_COLUMNS], Array)
        error(ERROR_STRUCTURE_COLUMNS)
    end
end

function has_key_with_type(col_config::Dict, col_key::String, type::Type)
    !haskey(col_config, col_key) || !isa(col_config[col_key], type)
end

function find_name_with_invalid_require_missing(cols::Array)
    index = findfirst(cols) do col_config
        haskey(col_config, KEY_COLUMN_REPLACE_MISSING) && !isa(col_config[KEY_COLUMN_REPLACE_MISSING], Array)
    end
    index == nothing ? nothing : cols[index][KEY_COLUMN_NAME]
end

function find_name_with_invalid_type(cols::Array)
    index = findfirst(cols) do col_config
        col_config[KEY_COLUMN_TYPE] != VALUE_COLUMN_TYPE_STRING &&
            col_config[KEY_COLUMN_TYPE] != VALUE_COLUMN_TYPE_NUMBER
    end
    index == nothing ? nothing : cols[index][KEY_COLUMN_NAME]
end

function find_name_with_duplicate_config(cols::Array)
    has_name_been_seen = Set()
    duplicate_name = nothing
    for col_config in cols
        if col_config[KEY_COLUMN_NAME] in has_name_been_seen
            duplicate_name = col_config[KEY_COLUMN_NAME]
            break
        else
            push!(has_name_been_seen, col_config[KEY_COLUMN_NAME])
        end
    end
    duplicate_name == nothing ? nothing : duplicate_name
end

function warn_unknown_props(config::Dict, known_props::Array; prefix = "Config")
    foreach(keys(config)) do prop_name
        if prop_name ∉ known_props
            @warn "$(prefix) has unknown key `$(prop_name)`"
        end
    end
end

end # module
