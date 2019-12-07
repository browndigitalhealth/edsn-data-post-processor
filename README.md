# EDSN Data Post Processor

Post process input and outcome data for the EDSN project into a single validated CSV file.

| Input | Output |
| ----- | ------ |
| CSV files each containing `patient_epic_id` (the study identifier) with associated inputs or outcomes | a single cleaned, validated CSV file containing all inputs and outcomes for each patient by `patient_epic_id` |

Out-of-memory processing of larger datasets via a temporary SQLite table with following structure:

* Rows are discovered subjects
* Columns are all specified columns in the config
* Resulting matrix contains validated data values, standardized missing tokens, or invalid tokens for data values that do not match stated column type

## YAML config properties

* Script will exit immediately
    * If any of the required properties are not provided
    * If a config property has an invalid type or value
    * If a study ID column cannot be found in every single CSV file
    * If the same column (by name) has multiple configs
    * If passed in input folder is not actually a folder
* Script will print a warning but will not exit
    * If a column config is provided that doesn’t match any of the discovered columns
    * If any of the non study ID columns in any of the CSV files does not have a specified config
    * If an unknown config property is provided

### Global properties

* (required) `missing_token`: how to represent “missing” in the dataset
* (required) `invalid_token`: how to represent data values that could not be converted to the data type specified in the column config
* (required) `study_id_column_name`: name of the column that is the study ID. This will be used to cross-reference CSV files. If a CSV file does not have this study ID column, this script will exit with error

### Column properties

Each column (input or outcome) except the study ID column needs to have the following config properties

* (required) `column_name`: name of the column. This must be the exact same as how the column name is represented in the CSV files, including all punctuation, spacing, and letter case.
* (required) `data_type`: how the data should be transformed, if needed. Must be either string or number
* If a value cannot be transformed, the script will replace with the specified `invalid_token`
* (optional) `replace_with_missing`: a list of values to replace with the missing token provided in the global properties
* (optional) `convert_missing_token_to_value`: convert all instances of the globally-specified missing token to this specified value, this is particularly useful if your query does not return all subjects so that subjects that this column doesn't have data for aren't really missing but rather not represented in the calculation output

## Sample YAML config

```yaml
global:
  missing_token: "***missing***"
  invalid_token: "***invalid***"
  study_id_column_name: patient_epic_id
columns:
  - column_name: input_v1
    data_type: string
    replace_with_missing:
      - 0
      - -1
  - column_name: input_v2
    data_type: number
  - column_name: input_v3
    data_type: string
    replace_with_missing:
      - "not applicable"
  - column_name: input_v4
    data_type: number
    replace_with_missing:
      - "n/a"
    convert_missing_token_to_value: 0
```
