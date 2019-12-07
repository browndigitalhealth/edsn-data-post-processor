module DbUtils

include("Utils.jl")

import CSV
import SQLite

const TABLE_NAME = "temp_table"

export with_temp_db
function with_temp_db(fn::Function, subjects::AbstractVector, columns::AbstractVector;
        id_col::AbstractString, missing_token::AbstractString,
        col_missing_tokens::AbstractDict{String, Any})

    # DO NOT create an in-memory SQLite database because the data may be too large for memory
    temp_name = tempname()
    try
        db = SQLite.DB(temp_name)
        col_defs = []
        uniq_subjects = unique(subjects)
        uniq_columns = unique(columns)

        # creating table with missing token as default values
        for col_name in uniq_columns
            push!(col_defs, col_def(col_name,
                primary = (col_name == id_col),
                missing_token = get(col_missing_tokens, col_name, missing_token)))
        end
        SQLite.execute!(db, "CREATE TABLE $(TABLE_NAME) ($(join(col_defs, ", ")))")

        # insert all subjects as rows within a single transaction for maximal performance
        try_start_transaction!(db)
        stmt = SQLite.Stmt(db, """
            INSERT INTO $(TABLE_NAME) ($(Utils.clean_db_word(id_col))) VALUES(?)
        """)
        for subject in uniq_subjects
            SQLite.bind!(stmt, 1, subject)
            SQLite.execute!(stmt)
        end
        try_commit_transaction!(db)

        # allow whatever work we need to do on this temp db before cleaning up
        fn(db, TABLE_NAME)
    finally
        # delete temp SQLite db, force true in case the db hasn't been closed yet
        rm(temp_name, force = true)
    end
end

export try_start_transaction!
function try_start_transaction!(db::SQLite.DB)
    try
        SQLite.execute!(db, "BEGIN TRANSACTION")
    catch e
        @warn e
    end
end

export try_commit_transaction!
function try_commit_transaction!(db::SQLite.DB)
    try
        SQLite.execute!(db, "COMMIT")
    catch e
        @warn e
    end
end

export try_insert_value!
function try_insert_value!(new_val; db::SQLite.DB, table_name::AbstractString,
    column::AbstractString, id_col::AbstractString, subject::AbstractString)

    # we will NOT execute an update statement for missing because default already is missing token
    if !ismissing(new_val)
        SQLite.execute!(db, """
            UPDATE $(table_name)
            SET $(Utils.clean_db_word(column)) = '$(Utils.clean_db_value(new_val))'
            WHERE $(Utils.clean_db_word(id_col)) = '$(Utils.clean_db_value(subject))'
        """)
    end
end

export export_db!
function export_db!(output_path; db::SQLite.DB, table_name::AbstractString)
    SQLite.Query(db, "SELECT * FROM $(table_name)") |> CSV.write(output_path)
end

# Helpers
# -------

function col_def(col_name; missing_token = "", primary = false)
    def = "$(Utils.clean_db_word(col_name))"
    if primary
        def *= " PRIMARY KEY"
    end
    if missing_token != ""
        def *= " DEFAULT '$(Utils.clean_db_value(missing_token))'"
    end
    def
end

end # module
