#!/bin/bash
# Lab1: DDB. Aleksei Kutsenko
# Variant 712

# shellcheck disable=SC2028

function help() {
  # Display Help
  echo
  echo "Lab work 1. Author: Kutsenko Aleksei. Variant 712"
  echo "Possible usage:"
  echo
  echo "./run TABLE_NAME"
  echo "    This will print you info about desirable table for each found table in all accessible schemas"
  echo
  echo "./run SCHEMA_NAME.TABLE_NAME"
  echo "    This will print you info about desirable table in given schema"
  echo
}

function write_file_to_find_table() {
  echo "
  drop function if exists get_info_about_table_by_name(table_name varchar);

  create or replace function get_info_about_table_by_name(table_name varchar)
      returns table
              (
                  №             bigint,
                  \"Имя столбца\" name,
                  \"Атрибуты\"   text
              )
      language plpgsql as
  \$func\$
  BEGIN
  return query select row_number() over () as №,
                          columns.attname as \"Имя столбца\",
                          concat('Type ',': ',pt.typname, ' ', (case columns.attnotnull when false then 'NULL' else 'NOT NULL' end), E'\n', 'Comment ', ': ', pd.description, E'\n', 'Constr ', ': ', (case constraints.consrc when null then 'Empty' else constraints.consrc end), E'\n') as "Атрибуты"
                   FROM pg_attribute columns
                            inner join pg_class tables
                                       on columns.attrelid = tables.oid
                            inner join pg_type pt
                                       on columns.atttypid = pt.oid
                            left join pg_namespace n on n.oid = tables.relnamespace
                            left join pg_tablespace t on t.oid = tables.reltablespace
                            left join pg_description pd on (pd.objoid = tables.oid  and pd.objsubid = columns.attnum)
                            left join pg_constraint constraints
                                      on constraints.conrelid = columns.attrelid and columns.attnum = any(constraints.conkey)
                   where tables.relname = table_name and columns.attnum > 0;
  end;
  \$func\$;
  " > .file1.sql

  echo "select * from get_info_about_table_by_name('$1');" > .file2.sql

}

function execute_psql_commands() {
  psql -U $USER -h pg -d studs -f .file1.sql
  psql -U $USER -h pg -d studs -f .file2.sql
}
function get_schemas_names() {
  echo "
  CREATE OR REPLACE FUNCTION schemas_table(t text)
      RETURNS VOID AS
  \$\$
  DECLARE
  schema_tab CURSOR FOR (
          SELECT tab.relname, space.nspname FROM pg_class tab
                                                     JOIN pg_namespace space on tab.relnamespace = space.oid
          WHERE (tab.relname = t or (tab.relname = (SELECT SPLIT_PART(t,'.',2))) AND (space.nspname = (SELECT SPLIT_PART(t,'.',1)))) OR ((tab.relname = (SELECT SPLIT_PART(t,'.',3))) and space.nspname = (SELECT SPLIT_PART(t,'.',2)))
          ORDER BY space.nspname
      );
      table_count int;
  schema text;
  BEGIN

  SELECT COUNT(DISTINCT nspname) INTO table_count FROM pg_class tab JOIN pg_namespace space on tab.relnamespace = space.oid WHERE relname = t;

  IF table_count < 0 THEN
          RAISE EXCEPTION 'Таблица \"%\" не найдена!', t;
  ELSE

  FOR col in schema_tab
              LOOP
                  RAISE NOTICE '%', col.nspname;
  END LOOP;
          RAISE NOTICE ' ';
  END IF;
  END
  \$\$ LANGUAGE plpgsql;


  " > .file3.sql
  echo "SELECT schemas_table('$1');" > .file4.sql
  psql -U $USER -h pg -d studs -f .file3.sql
  psql -U $USER -h pg -d studs -f .file4.sql 2>&1  | sed -e "s|.*NOTICE: ||g" | tail +3 | head -n +3

}
function clean_temp_files() {
  rm .file*.sql
}

##################
###   script   ###
##################

while getopts ":h" option; do
  # shellcheck disable=SC2220
  case $option in
    h)
      help
      exit;
    \? # incorrect option
      echo "Error: Invalid option"
      exit;
  esac
done

if [ -n "$1" ]
then
  IFS='.'
  read -a str <<< "$1"

  echo "Пользователь: $USER"

  if [ ${#str[@]} -eq 1 ]; then
      echo "Таблица: $1"
      write_file_to_find_table $1
      get_schemas_names $1
      schemas="{$(execute_psql_commands $1)}"
      echo "$schemas"


  elif [ ${#str[@]} -eq 2 ]; then
      echo -e "Схема:\t${str[0]}"
      echo -e "Таблица:\t${str[1]}"


  elif [ ${#str[@]} -eq 3 ]; then
      echo -e "БД:\t${str[0]}"
      echo -e "Схема:\t${str[1]}"
      echo -e "Таблица:\t${str[2]}"

  elif [ ${#str[@]} -gt 3 ]; then
      echo "Слишком длинная последовательность"


  fi
clean_temp_files
else
  echo "Пожалуйста сообщите название таблицы"
fi

