module Constants

export ERROR_STRUCTURE_GLOBAL, ERROR_STRUCTURE_COLUMNS, ERROR_REQUIRED_GLOBAL, ERROR_REQUIRED_COLUMN
const ERROR_STRUCTURE_GLOBAL = "Config must provide a dictionary for the `global` key"
const ERROR_STRUCTURE_COLUMNS = "Config must provide a list of dictionaries for the `columns` key"
const ERROR_REQUIRED_GLOBAL = "Config `global` key must specify strings for both `missing_token` and `study_id_column_name`"
const ERROR_REQUIRED_COLUMN = "Each column config must specify strings for both `column_name` and `data_type`"

export KEY_GLOBAL, KEY_GLOBAL_MISSING, KEY_GLOBAL_STUDY_ID, KEY_COLUMNS, KEY_COLUMN_NAME, KEY_COLUMN_TYPE, KEY_COLUMN_REPLACE_MISSING
const KEY_GLOBAL = "global"
const KEY_GLOBAL_MISSING = "missing_token"
const KEY_GLOBAL_STUDY_ID = "study_id_column_name"
const KEY_COLUMNS = "columns"
const KEY_COLUMN_NAME = "column_name"
const KEY_COLUMN_TYPE = "data_type"
const KEY_COLUMN_REPLACE_MISSING = "replace_with_missing"

export VALUE_COLUMN_TYPE_STRING, VALUE_COLUMN_TYPE_NUMBER
const VALUE_COLUMN_TYPE_STRING = "string"
const VALUE_COLUMN_TYPE_NUMBER = "number"

end # module
