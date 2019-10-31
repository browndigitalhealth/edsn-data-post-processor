include("../src/modules/Constants.jl")

import DataPostProcessor
using .Constants
using Test

@testset "config validation will exit immediately" begin
    @testset "if the provided path does not point to a valid YAML file" begin
        # nonexistent file
        @test_throws SystemError DataPostProcessor.validate_config("nonexistent")

        # invalid YAML file
        path = pwd() * "/data/config/fail_invalid_overall_structure.yaml"
        @test_throws ErrorException DataPostProcessor.validate_config(path)
    end

    @testset "if the overall structure of the config file is invalid" begin
        path = pwd() * "/data/config/fail_invalid_overall_structure_global.yaml"
        error_msg = ERROR_STRUCTURE_GLOBAL
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_config(path)

        path = pwd() * "/data/config/fail_invalid_overall_structure_columns.yaml"
        error_msg = ERROR_STRUCTURE_COLUMNS
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_config(path)
    end

    @testset "if any of the required global properties are not provided" begin
        path = pwd() * "/data/config/fail_missing_required_global.yaml"
        error_msg = ERROR_REQUIRED_GLOBAL
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_config(path)
    end

    @testset "if any of the required column properties are not provided" begin
        path = pwd() * "/data/config/fail_missing_required_column.yaml"
        error_msg = ERROR_REQUIRED_COLUMN
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_config(path)
    end

    @testset "if a config property has an invalid type or value" begin
        # When the `replace_with_missing` property is not an array
        path = pwd() * "/data/config/fail_invalid_type_replace_with_missing.yaml"
        error_msg = "Config for column `input_v1` has key `replace_with_missing` that is not an array"
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_config(path)

        # When the `data_type` property is not either `string` or `number`
        path = pwd() * "/data/config/fail_invalid_value_data_type.yaml"
        error_msg = "Config for column `input_v1` has key `data_type` that is not either `string` or `number`"
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_config(path)
    end

    @testset "if the same column (by name) has multiple configs" begin
        path = pwd() * "/data/config/fail_duplicate_column_configs.yaml"
        error_msg = "Duplicate configs found for column `input_v1`"
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_config(path)
    end
end

@testset "config validation will print a warning but will not exit" begin
    @testset "if an unknown config property is provided" begin
        path = pwd() * "/data/config/warn_unknown_config_properties.yaml"
        @test_logs((:warn, "Config has unknown key `unknown_global_prop`"),
            (:warn, "Config for column `input_v1` has unknown key `unknown_column_prop_1`"),
            (:warn, "Config for column `input_v3` has unknown key `unknown_column_prop_2`"),
            DataPostProcessor.validate_config(path))
    end
end

@testset "config validation will succeed on valid files" begin
    # valid YAML file
    path = pwd() * "/data/config/valid.yaml"
    @test_nowarn DataPostProcessor.validate_config(path)
end

@testset "validating config in context of the provided CSV input files" begin
    @testset "exit with error if input file path is not a directory" begin
        config = pwd() * "/data/config/valid.yaml"
        input_folder = pwd() * "/data/csv/not a real directory"
        error_msg = ERROR_INPUT_FOLDER
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_input_files(config, input_folder)
    end

    @testset "exit with error if a study ID column cannot be found in every provided CSV file" begin
        config = pwd() * "/data/config/valid.yaml"
        input_folder = pwd() * "/data/csv/no_subject_id"
        error_msg = "File `no_subject_id.csv` is missing subject ID `subject_id`"
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_input_files(config, input_folder)
    end

    @testset "exit with error if a multiple columns with same name found in CSV files" begin
        config = pwd() * "/data/config/valid.yaml"
        input_folder = pwd() * "/data/csv/duplicate_columns"
        error_msg = "Multiple data columns in the input files found for `input_v1`"
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_input_files(config, input_folder)
    end

    @testset "warn if config is missing a column that is found in the input files" begin
        config = pwd() * "/data/config/valid.yaml"
        input_folder = pwd() * "/data/csv/excess_columns"
        @test_logs((:warn, "Found data for column `input_v4` but could not find config. Ignoring..."),
            DataPostProcessor.validate_input_files(config, input_folder))
    end

    @testset "warn if config has a column that cannot be found in the input files" begin
        config = pwd() * "/data/config/valid.yaml"
        input_folder = pwd() * "/data/csv/missing_columns"
        @test_logs((:warn, "Found config for column `input_v1` but could not find data. Ignoring..."),
            DataPostProcessor.validate_input_files(config, input_folder))
    end
end

# # TODO
# @testset "replacing designated missing values with config's missing token" begin

# end

# # TODO
# @testset "error when converting data in a column to specified type" begin

# end

# # TODO
# @testset "success when converting data in a column to specified type" begin

# end

# # TODO
# @testset "subjects found in one file but not another have missing tokens filled in" begin

# end

# # TODO
# @testset "successfully clean and unify a set of CSV files given valid config" begin

# end
