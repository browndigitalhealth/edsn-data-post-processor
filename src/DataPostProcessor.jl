module DataPostProcessor

include("modules/ConfigUtils.jl")
include("modules/Constants.jl")
include("modules/DataUtils.jl")
include("modules/DbUtils.jl")
include("modules/Utils.jl")

import CSV
import YAML
using .Constants

export validate_inputs
function validate_inputs(config_path::AbstractString, input_files_path::AbstractString)
    config = YAML.load_file(config_path)
    ConfigUtils.check_error_and_exit_conditions(config)
    ConfigUtils.check_warn_conditions(config)
    ConfigUtils.check_csv_files(config, input_files_path)
    config
end

export process_data!
function process_data!(config_path::AbstractString, input_files_path::AbstractString, output_path::AbstractString)
    config = validate_inputs(config_path, input_files_path)

    missing_token = Utils.get_missing_token(config)
    invalid_token = Utils.get_invalid_token(config)
    id_col = Utils.get_id_col(config)

    col_configs::Dict{String, Any} = ConfigUtils.build_col_configs(config)
    subjects = DataUtils.find_subjects(input_files_path,
        id_col = id_col,
        missing_token = missing_token) do file_name, num_missing
        if num_missing > 0
            error("File `$(file_name)` has $(num_missing) missing value(s). All subject IDs must be present.")
        end
    end

    DbUtils.with_temp_db(subjects, ConfigUtils.build_db_col_names(config),
        id_col = id_col,
        missing_token = missing_token,
        col_missing_tokens = ConfigUtils.build_col_missing_tokens(config)) do db, table_name
        # for each input CSV file
        DbUtils.try_start_transaction!(db)
        Utils.with_csv_file_names(input_files_path) do file_name
            rows = CSV.Rows(file_name)
            file_non_id_cols = Utils.exclude_val(id_col, map(String, rows.names))
            # only iterate through rows of each file once
            for row in rows
                # for each non-study column
                for col_name in file_non_id_cols
                    # ignore all columns without a config
                    if haskey(col_configs, col_name)
                        new_val = DataUtils.try_validate_value(Utils.csv_row_prop(row, col_name),
                            missing_token = missing_token,
                            invalid_token = invalid_token,
                            col_config = col_configs[col_name])
                        DbUtils.try_insert_value!(new_val,
                            db = db,
                            table_name = table_name,
                            column = col_name,
                            id_col = id_col,
                            subject = Utils.csv_row_prop(row, id_col))
                    end
                end
            end
        end
        DbUtils.try_commit_transaction!(db)

        # entire table export to output CSV
        DbUtils.export_db!(output_path,
            db = db,
            table_name = table_name)
    end
end

end # module
