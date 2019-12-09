module DataUtils

include("Constants.jl")
include("Utils.jl")

import CSV
using .Constants

export find_subjects
function find_subjects(; id_col::AbstractString, missing_token::AbstractString,
    input_files_path::AbstractString, filter_subjects_file::Union{AbstractString, Nothing})

    find_subjects(FN_NO_OP;
        id_col = id_col,
        missing_token = missing_token,
        input_files_path = input_files_path,
        filter_subjects_file = filter_subjects_file)
end
function find_subjects(fn::Function; id_col::AbstractString, missing_token::AbstractString,
    input_files_path::AbstractString, filter_subjects_file::Union{AbstractString, Nothing})

    subjects = []
    if isnothing(filter_subjects_file)
        Utils.with_csv_file_names(input_files_path) do file_name
            append!(subjects, find_subjects_from_files(fn, file_name,
                id_col = id_col,
                missing_token = missing_token))
        end
    else
        col_names = build_cols_for_file(filter_subjects_file)
        if !(id_col in col_names)
            error(ERROR_FILTER_WRONG_COLUMN_NAME)
        end
        append!(subjects, find_subjects_from_files(fn, filter_subjects_file,
            id_col = id_col,
            missing_token = missing_token))
    end
    subjects
end

export find_all_cols
function find_all_cols(fn::Function, input_files_path::AbstractString; allow_duplicates::Bool,
    exclude_id_col_on_return::AbstractString)
    all_csv_col_names = []
    # collect column names from all CSV files
    Utils.with_csv_file_names(input_files_path) do file_name
        col_names = build_cols_for_file(file_name)
        fn(file_name, col_names)
        append!(all_csv_col_names, col_names)
    end
    if !allow_duplicates
        unique!(all_csv_col_names)
    end
    exclude_id_col_on_return == "" ?
        all_csv_col_names :
        Utils.exclude_val(exclude_id_col_on_return, all_csv_col_names)
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

# Helpers
# -------

function build_cols_for_file(file_name::AbstractString)
    # assume first line is CSV header
    # we need to manually inspect the header this way because the CSV library will automatically
    # name columns with duplicate names
    split(readline(file_name), ",")
end

function find_subjects_from_files(fn::Function, file_name::AbstractString;
    id_col::AbstractString, missing_token::AbstractString)

    subjects = []
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
    subjects
end

end # module
