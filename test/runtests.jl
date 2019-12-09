include("../src/modules/Constants.jl")

import CSV
import DataPostProcessor
using .Constants
using Test

@testset "config validation will exit immediately" begin
    @testset "if the provided path does not point to a valid YAML file" begin
        # nonexistent file
        path = "nonexistent"
        input_folder = pwd() * "/data/csv/valid"
        @test_throws SystemError DataPostProcessor.validate_inputs(path, input_folder)

        # invalid YAML file
        path = pwd() * "/data/config/fail_invalid_overall_structure.yaml"
        input_folder = pwd() * "/data/csv/valid"
        @test_throws ErrorException DataPostProcessor.validate_inputs(path, input_folder)
    end

    @testset "if the overall structure of the config file is invalid" begin
        path = pwd() * "/data/config/fail_invalid_overall_structure_global.yaml"
        input_folder = pwd() * "/data/csv/valid"
        error_msg = ERROR_STRUCTURE_GLOBAL
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_inputs(path, input_folder)

        path = pwd() * "/data/config/fail_invalid_overall_structure_columns.yaml"
        input_folder = pwd() * "/data/csv/valid"
        error_msg = ERROR_STRUCTURE_COLUMNS
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_inputs(path, input_folder)
    end

    @testset "if any of the required global properties are not provided" begin
        path = pwd() * "/data/config/fail_missing_required_global.yaml"
        input_folder = pwd() * "/data/csv/valid"
        error_msg = ERROR_REQUIRED_GLOBAL
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_inputs(path, input_folder)
    end

    @testset "if any of the required column properties are not provided" begin
        path = pwd() * "/data/config/fail_missing_required_column.yaml"
        input_folder = pwd() * "/data/csv/valid"
        error_msg = ERROR_REQUIRED_COLUMN
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_inputs(path, input_folder)
    end

    @testset "if a config property has an invalid type or value" begin
        # When the `replace_with_missing` property is not an array
        path = pwd() * "/data/config/fail_invalid_type_replace_with_missing.yaml"
        input_folder = pwd() * "/data/csv/valid"
        error_msg = "Config for column `input_v1` has key `replace_with_missing` that is not an array"
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_inputs(path, input_folder)

        # When the `data_type` property is not either `string` or `number`
        path = pwd() * "/data/config/fail_invalid_value_data_type.yaml"
        input_folder = pwd() * "/data/csv/valid"
        error_msg = "Config for column `input_v1` has key `data_type` that is not either `string` or `number`"
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_inputs(path, input_folder)
    end

    @testset "if the same column (by name) has multiple configs" begin
        path = pwd() * "/data/config/fail_duplicate_column_configs.yaml"
        input_folder = pwd() * "/data/csv/valid"
        error_msg = "Duplicate configs found for column `input_v1`"
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_inputs(path, input_folder)
    end
end

@testset "config validation will print a warning but will not exit" begin
    @testset "if an unknown config property is provided" begin
        path = pwd() * "/data/config/warn_unknown_config_properties.yaml"
        input_folder = pwd() * "/data/csv/valid"
        @test_logs((:warn, "Config has unknown key `unknown_global_prop`"),
            (:warn, "Config for column `input_v1` has unknown key `unknown_column_prop_1`"),
            (:warn, "Config for column `input_v3` has unknown key `unknown_column_prop_2`"),
            DataPostProcessor.validate_inputs(path, input_folder))
    end
end

@testset "config validation will succeed on valid files" begin
    # valid YAML file
    path = pwd() * "/data/config/valid.yaml"
    input_folder = pwd() * "/data/csv/valid"
    @test_nowarn DataPostProcessor.validate_inputs(path, input_folder)
end

@testset "validating config in context of the provided CSV input files" begin
    @testset "exit with error if input file path is not a directory" begin
        config = pwd() * "/data/config/valid.yaml"
        input_folder = pwd() * "/data/csv/not a real directory"
        error_msg = ERROR_INPUT_FOLDER
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_inputs(config, input_folder)
    end

    @testset "exit with error if a study ID column cannot be found in every provided CSV file" begin
        config = pwd() * "/data/config/valid.yaml"
        input_folder = pwd() * "/data/csv/no_subject_id"
        error_msg = "File `no_subject_id.csv` is missing subject ID column `subject_id`"
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_inputs(config, input_folder)
    end

    @testset "exit with error if a multiple columns with same name found in CSV files" begin
        config = pwd() * "/data/config/valid.yaml"
        input_folder = pwd() * "/data/csv/duplicate_columns"
        error_msg = "Multiple data columns in the input files found for `input_v1`"
        @test_throws ErrorException(error_msg) DataPostProcessor.validate_inputs(config, input_folder)
    end

    @testset "warn if config is missing a column that is found in the input files" begin
        config = pwd() * "/data/config/valid.yaml"
        input_folder = pwd() * "/data/csv/excess_columns"
        @test_logs((:warn, "Found data for column `input_v4` but could not find config. Ignoring..."),
            DataPostProcessor.validate_inputs(config, input_folder))
    end

    @testset "warn if config has a column that cannot be found in the input files" begin
        config = pwd() * "/data/config/valid.yaml"
        input_folder = pwd() * "/data/csv/missing_columns"
        @test_logs((:warn, "Found config for column `input_v1` but could not find data. Ignoring..."),
            DataPostProcessor.validate_inputs(config, input_folder))
    end
end

@testset "script cleans up any temporary files it generates" begin
    temp_dir = tempdir()
    files_before = readdir()
    temp_files_before = readdir(temp_dir)
    config = pwd() * "/data/config/valid.yaml"
    input_folder = pwd() * "/data/csv/single_valid"
    output_file = tempname()

    DataPostProcessor.process_data!(config, input_folder, output_file)

    # specified output file is indeed created
    @test isfile(output_file)
    # current directory has no new files
    @test isempty(setdiff(readdir(), files_before))
    # the only net new temp file is the output file. Any transient db file is deleted on cleanup
    @test setdiff(readdir(temp_dir), temp_files_before) ==
        [replace(output_file, (temp_dir * "/") => "")] # extract only the file name from the path
end

@testset "exit with error if any missing values in subject id column" begin
    config = pwd() * "/data/config/valid.yaml"
    input_folder = pwd() * "/data/csv/missing_subject_ids"
    output_file = tempname()
    error_msg = "File `missing_subject_ids.csv` has 1 missing value(s). All subject IDs must be present."

    @test_throws ErrorException(error_msg) DataPostProcessor.process_data!(config, input_folder, output_file)
end

@testset "replacing designated missing values with config's missing token" begin
    config = pwd() * "/data/config/valid.yaml"
    input_folder = pwd() * "/data/csv/single_valid"
    output_file = tempname()

    DataPostProcessor.process_data!(config, input_folder, output_file)

    df = CSV.read(output_file)

    # CSV.read will not perform type inference so everything is a string
    @test df[!, :input_v2] == [
        "2.1",
        "***missing***",
        "4.3",
        "5.4",
        "7.6",
        "***missing***", # replaced with missing
        "88",
        "10.9",
    ]
    @test df[!, :input_v3] == [
        "kiki",
        "yes",
        "***missing***",
        "***missing***", # replaced with missing
        "secure",
        "the",
        "***missing***", # replaced with missing
        "bag",
    ]
end

@testset "convert data in a columns to specified types" begin
    config = pwd() * "/data/config/valid.yaml"
    input_folder = pwd() * "/data/csv/type_conversion"
    output_file = tempname()

    DataPostProcessor.process_data!(config, input_folder, output_file)

    df = CSV.read(output_file)

    # CSV.read will not perform type inference so everything is a string
    # replace with invalid and print warning when unable to convert
    @test df[!, :input_v2] == [
        "2.1",
        "***missing***",
        "4.3",
        "5.4",
        "***invalid***", # unable to convert
        "***missing***", # replaced with missing
        "88",
        "10.9",
    ]

    # keep converted value if able to successfully convert
    @test df[!, :input_v3] == [
        "kiki's love", # test handling of single quotes
        "yes",
        "***missing***",
        "***missing***", # replaced with missing
        "secure",
        "the",
        "***missing***", # replaced with missing
        "bag",
    ]
end

@testset "subjects found in one file but not another have missing tokens filled in" begin
    config = pwd() * "/data/config/valid.yaml"
    input_folder = pwd() * "/data/csv/valid"
    output_file = tempname()

    DataPostProcessor.process_data!(config, input_folder, output_file)

    df = CSV.read(output_file)

    # person 1 in file 1 but not in file 2
    person1 = filter(row -> row.subject_id == "person 1", df)
    @test person1.input_v1[1] == "hello"
    @test person1.input_v2[1] == "***missing***" # not in file
    @test person1.input_v3[1] == "***missing***" # not in file

    # person 2 in file 2 but not in file 1
    person2 = filter(row -> row.subject_id == "person 2", df)
    @test person2.input_v1[1] == "***missing***" # not in file
    @test person2.input_v2[1] == "2.1" # CSV.read will not perform type inference so everything is a string
    @test person2.input_v3[1] == "kiki"

    # person 9 in both files
    person9 = filter(row -> row.subject_id == "person 9", df)
    @test person9.input_v1[1] == "great"
    @test person9.input_v2[1] == "88" # CSV.read will not perform type inference so everything is a string
    @test person9.input_v3[1] == "***missing***" # replaced with missing
end

@testset "successfully clean and unify a set of CSV files given valid config" begin
    config = pwd() * "/data/config/valid.yaml"
    input_folder = pwd() * "/data/csv/valid_with_extra_cols"
    output_file = tempname()

    DataPostProcessor.process_data!(config, input_folder, output_file)

    df = CSV.read(output_file)

    @test size(df, 1) == 10 # 10 subjects
    @test size(df, 2) == 4 # 4 columns, including the subject id column
    # extra column excluded from output file
    @test isempty(setdiff(names(df), [:subject_id, :input_v1, :input_v2, :input_v3]))
    @test isempty(setdiff(df.subject_id, [
        "person 1",
        "person 2",
        "person 3",
        "person 4",
        "person 5",
        "person 6",
        "person 7",
        "person 8",
        "person 9",
        "person 10",
    ]))
end

@testset "given a valid config, convert missing token to different value" begin
    config = pwd() * "/data/config/valid_convert_missing.yaml"
    input_folder = pwd() * "/data/csv/valid"
    output_file = tempname()

    DataPostProcessor.process_data!(config, input_folder, output_file)

    df = CSV.read(output_file)

    # 10 subjects because finds all subjects across all specified files
    @test size(df, 1) == 10
    @test size(df, 2) == 3 # 3 columns, including the subject id column
    # extra column excluded from output file
    @test isempty(setdiff(names(df), [:subject_id, :input_v2, :input_v3]))
    @test isempty(setdiff(df.subject_id, [
        "person 1",
        "person 2",
        "person 3",
        "person 4",
        "person 5",
        "person 6",
        "person 7",
        "person 8",
        "person 9",
        "person 10",
    ]))

    # input2 has no value for person1
    person1 = filter(row -> row.subject_id == "person 1", df)
    @test person1.input_v2[1] == -888.2
    # input2 has pre-existing missing token for person3
    person3 = filter(row -> row.subject_id == "person 3", df)
    @test person3.input_v2[1] == -888.2
    # input2 has no value for person6
    person6 = filter(row -> row.subject_id == "person 6", df)
    @test person6.input_v2[1] == -888.2
    # input2 has value replaced with missing token for person8
    person8 = filter(row -> row.subject_id == "person 8", df)
    @test person8.input_v2[1] == -888.2
    # input2 has existing, non-missing value for for person10
    person10 = filter(row -> row.subject_id == "person 10", df)
    @test person10.input_v2[1] == 10.9

    # input3 has no value for person1
    person1 = filter(row -> row.subject_id == "person 1", df)
    @test person1.input_v3[1] == "***missing***"
    # input3 has value replaced with missing token for person2
    person2 = filter(row -> row.subject_id == "person 2", df)
    @test person2.input_v3[1] == "***missing***"
    # input3 has pre-existing missing token for person4
    person4 = filter(row -> row.subject_id == "person 4", df)
    @test person4.input_v3[1] == "***missing***"
    # input3 has no value for person6
    person6 = filter(row -> row.subject_id == "person 6", df)
    @test person6.input_v3[1] == "***missing***"
    # input3 has existing, non-missing value for for person10
    person10 = filter(row -> row.subject_id == "person 10", df)
    @test person10.input_v3[1] == "bag"
end

@testset "specifying subject ids to filter output by" begin
    @testset "subject ids to filter by must have matching `study_id_column_name`" begin
        config = pwd() * "/data/config/valid.yaml"
        input_folder = pwd() * "/data/csv/valid"
        filter_file = pwd() * "/data/filter/wrong_column_name.csv"
        output_file = tempname()
        error_msg = ERROR_FILTER_WRONG_COLUMN_NAME

        @test_throws ErrorException(error_msg) DataPostProcessor.process_data!(config, input_folder, output_file,
            filter_subjects_file = filter_file)
    end

    @testset "subject ids to filter by must not have any missing values" begin
        config = pwd() * "/data/config/valid.yaml"
        input_folder = pwd() * "/data/csv/valid"
        filter_file = pwd() * "/data/filter/some_missing.csv"
        output_file = tempname()
        error_msg = ERROR_FILTER_MISSING_VALUES

        @test_throws ErrorException(error_msg) DataPostProcessor.process_data!(config, input_folder, output_file,
            filter_subjects_file = filter_file)
    end

    @testset "can ensure output only has specified subject ids" begin
        config = pwd() * "/data/config/valid.yaml"
        input_folder = pwd() * "/data/csv/valid"
        filter_file = pwd() * "/data/filter/valid.csv"
        output_file = tempname()

        DataPostProcessor.process_data!(config, input_folder, output_file,
            filter_subjects_file = filter_file)

        df = CSV.read(output_file)

        # only the subject ids listed in the filter file are shown in the output
        @test size(df, 1) == 5
        @test isempty(setdiff(df.subject_id, [
            "person 1",
            "person 2",
            "person 3",
            "person 4",
            "person 5",
        ]))
    end
end
