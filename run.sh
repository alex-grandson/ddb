#!/bin/bash
# Lab1: DDB. Aleksei Kutsenko
# Variant 712

# shellcheck disable=SC2028

function help() {
  # Display Help
  echo
  echo "Lab work 1. Студент: Куценко Алексей. Вариант 712"
  echo "Использование:"
  echo
  echo "./run TABLE_NAME"
  echo "    Команда покажет в каких схемах имеется желаемая таблица"
  echo
  echo "./run SCHEMA_NAME.TABLE_NAME"
  echo "    This will print you info about desirable table in given schema"
  echo
}

function tableinfo_by_tablename() {
  echo "
  CREATE OR REPLACE FUNCTION get_name_by_oid(oid_number INT)
  RETURNS TEXT
  AS
  \$\$
      DECLARE
          tablename TEXT;
      BEGIN
          SELECT
              c.relname AS tablename INTO tablename
          FROM pg_class c
                   INNER JOIN pg_namespace n ON (c.relnamespace = n.oid)
          WHERE c.relfilenode = oid_number;
          RETURN tablename;
      END;
  \$\$ language plpgsql;

  DO
  \$\$
      DECLARE
          new_tab CURSOR FOR (
              SELECT DISTINCT ON (attnum) * FROM (
             SELECT DISTINCT ON (attname) attnum, attname, typname, description, consrc, conname, confrelid
             from pg_attribute columns
                      left join pg_class tables on columns.attrelid = tables.oid
                      left join pg_type pt on columns.atttypid = pt.oid
                      left join pg_namespace n on n.oid = tables.relnamespace
                      left join pg_tablespace t on t.oid = tables.reltablespace
                      left join pg_description pd on (pd.objoid = tables.oid  and pd.objsubid = columns.attnum)
                      left join pg_constraint constraints on constraints.conrelid = columns.attrelid and columns.attnum = any(constraints.conkey)
             WHERE (relname = '$1' or relname = SPLIT_PART('$1','.',2) or relname = SPLIT_PART('$1','.',3)) and attnum > 0
         ) as Foo
              ORDER BY attnum
          );
      BEGIN

          RAISE NOTICE ' ';
          RAISE NOTICE 'Пользователь: %', user;
          RAISE NOTICE 'Таблица: %', '$1';
          RAISE NOTICE ' ';
          RAISE NOTICE 'No.  Имя столбца      Атрибуты';
          RAISE NOTICE '---  --------------   -------------------------------------------------';

          FOR col IN new_tab
              LOOP
                  RAISE NOTICE '% % Type    : %', RPAD(col.attnum::text, 5, ' '), RPAD(col.attname, 16, ' '), col.typname;
                  IF col.confrelid != 0 THEN
                      RAISE NOTICE '% %', RPAD('⠀', 22, ' '),concat('Constr  : ', col.conname::text, ' References ', get_name_by_oid(col.confrelid::INT));
                  END IF;
                  RAISE NOTICE ' ';
              END LOOP;
      END;
  \$\$ LANGUAGE plpgsql;
  " > .table_info.sql

}

function table_info() {
  psql -U $USER -h pg -d studs -f .table_info.sql 2>&1 | sed -e "s|.*NOTICE: ||g"
}

function find_schemas_by_tablename() {
    echo "
    CREATE OR REPLACE FUNCTION schemas_table(t text)
        RETURNS VOID AS
    \$\$
    DECLARE
        schema_tab CURSOR FOR (
            SELECT tab.relname, space.nspname FROM pg_class tab
                   JOIN pg_namespace space on tab.relnamespace = space.oid
            WHERE (tab.relname = t)
            ORDER BY space.nspname
        );
        table_count int;
    BEGIN

        SELECT COUNT(DISTINCT nspname) INTO table_count FROM pg_class tab
            JOIN pg_namespace space on tab.relnamespace = space.oid
        WHERE relname = t;

        IF table_count < 0 THEN
            RAISE EXCEPTION 'Таблица "%" не найдена!', t;
        ELSE
            RAISE NOTICE ' ';
            RAISE NOTICE 'Схемы, где есть таблица %: ', t;

            FOR col in schema_tab
                LOOP
                    RAISE NOTICE '%', col.nspname;
                END LOOP;
            RAISE NOTICE ' ';
        END IF;
    END
    \$\$ LANGUAGE plpgsql;

    select * from schemas_table('$1');
    " > .find_schemas.sql
}

function find_schemas() {
  psql -U $USER -h pg -d studs -f .find_schemas.sql 2>&1 | sed -e "s|.*NOTICE: ||g"
}

function clean_temp_files() {
  rm .*.sql 2>/dev/null 1>/dev/null
  echo
}

######################################################
#####################   script   #####################
######################################################

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

  if [ ${#str[@]} -eq 1 ]; then
      echo "Пожалуйста укажите схему БД в вормате SCHEMA.TABLE"
      echo "Можете попробовать одну из представленых:"
      find_schemas_by_tablename $1
      find_schemas

  elif [ ${#str[@]} -eq 2 ]; then
      echo -e "Схема:\t${str[0]}"
      echo -e "Таблица:\t${str[1]}"
      tableinfo_by_tablename ${str[1]}
      table_info

  elif [ ${#str[@]} -gt 2 ]; then
      echo "Некорректный ввод"
  fi
clean_temp_files
else
  echo "Пожалуйста сообщите название таблицы"
fi

