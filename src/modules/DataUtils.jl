module DataUtils

include("Constants.jl")
include("Utils.jl")

import CSV
using .Constants

export find_subjects
function find_subjects(input_files_path::AbstractString; id_col::AbstractString,
    missing_token::AbstractString)

    find_subjects(FN_NO_OP, input_files_path; id_col = id_col, missing_token = missing_token)
end
function find_subjects(fn::Function, input_files_path::AbstractString; id_col::AbstractString,
    missing_token::AbstractString)

    subjects = []
    Utils.with_csv_file_names(input_files_path) do file_name
        num_missing = 0
        for row in CSV.Rows(file_name)
            subject = Utils.csv_row_prop(row, id_col)
            if subject == missing_token
                num_missing += 1
            else
                push!(subjects, subject)
            end
        end
        fn(file_name, num_missing)
    end
    subjects
end

export find_all_cols
function find_all_cols(fn::Function, input_files_path::AbstractString; allow_duplicates::Bool,
    exclude_id_col::AbstractString)
    all_csv_col_names = []
    # collect column names from all CSV files
    Utils.with_csv_file_names(input_files_path) do file_name
        # assume first line is CSV header
        # we need to manually inspect the header this way because the CSV library will automatically
        # name columns with duplicate names
        col_names = split(readline(file_name), ",")
        fn(file_name, col_names)
        append!(all_csv_col_names, col_names)
    end
    if !allow_duplicates
        unique!(all_csv_col_names)
    end
    exclude_id_col == "" ? all_csv_col_names : Utils.exclude_val(exclude_id_col, all_csv_col_names)
end

export try_validate_value
function try_validate_value(val; missing_token, invalid_token, col_config)
    if ismissing(val) || isnothing(val) || val == missing_token ||
        val in Utils.get_col_replace_missing(col_config)

        return missing
    end
    # try to convert to specified type, replace with invalid token if unable to convert
    if Utils.get_col_type(col_config) == VALUE_COLUMN_TYPE_STRING
        String(val)
    else # VALUE_COLUMN_TYPE_NUMBER
        new_val = tryparse(Float64, val)
        if isnothing(new_val)
            invalid_token
        elseif isinteger(new_val)
            Int(new_val)
        else
            new_val
        end
    end
end

end # module
