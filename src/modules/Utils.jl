module Utils

include("Constants.jl")

import CSV
using .Constants

const INVALID_DB_CHARS = r"\W+"

export find_first_duplicate
# Must be array cannot be set because we need to preserve duplicates
function find_first_duplicate(vals::AbstractVector)
    seen_vals = Set()
    first_dup = nothing
    for val in vals
        if val in seen_vals
            first_dup = val
            break
        else
            push!(seen_vals, val)
        end
    end
    isnothing(first_dup) ? nothing : first_dup
end

export exclude_val
function exclude_val(val_to_exclude, vals::AbstractVector)
    filter(val -> val !=  val_to_exclude, vals)
end

export with_csv_file_names
function with_csv_file_names(fn::Function, folder_path::AbstractString)
    cd(folder_path) do
        foreach(fn, filter(file -> endswith(file, ".csv"), readdir()))
    end
end

export clean_db_word
function clean_db_word(word::AbstractString)
    replace(word, INVALID_DB_CHARS => "_")
end

export clean_db_value
function clean_db_value(value::AbstractString)
    replace(value, "'" => "''")
end
function clean_db_value(value)
    value # no-op for non-strings
end

export csv_row_prop
function csv_row_prop(row::CSV.Row2, prop_name::AbstractString)
    getproperty(row, Symbol(prop_name))
end

export get_missing_token
function get_missing_token(config::AbstractDict)
    config[KEY_GLOBAL][KEY_GLOBAL_MISSING]
end

export get_invalid_token
function get_invalid_token(config::AbstractDict)
    config[KEY_GLOBAL][KEY_GLOBAL_INVALID]
end

export get_id_col
function get_id_col(config::AbstractDict)
    config[KEY_GLOBAL][KEY_GLOBAL_STUDY_ID]
end

export get_col_name
function get_col_name(col_config::AbstractDict)
    col_config[KEY_COLUMN_NAME]
end

export get_col_type
function get_col_type(col_config::AbstractDict)
    col_config[KEY_COLUMN_TYPE]
end

export get_col_replace_missing
function get_col_replace_missing(col_config::AbstractDict)
    haskey(col_config, KEY_COLUMN_REPLACE_MISSING) ?
        col_config[KEY_COLUMN_REPLACE_MISSING] :
        []
end

export get_col_convert_missing
function get_col_convert_missing(col_config::AbstractDict)
    haskey(col_config, KEY_COLUMN_CONVERT_MISSING) ?
        col_config[KEY_COLUMN_CONVERT_MISSING] :
        nothing
end

end # module
