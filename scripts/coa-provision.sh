#!/usr/bin/env bash

isSameFileAsYesterday() {
  file=$1
  echo $inducks_path_yesterday/$file
  return $(diff -q "$inducks_path_yesterday/$file" "$inducks_path/$file" > /dev/null 2>&1)
}

createFileWithAddedLinesSinceYesterdayForTable() {
  table=$1
  comm --nocheck-order -13 "$inducks_path_yesterday/$isv_subdir/$table.isv" "$inducks_path/$isv_subdir/$table.isv" > "$inducks_path/$isv_subdir/$table.added.isv"
}

createFileWithRemovedLinesSinceYesterdayForTable() {
  table=$1
  comm --nocheck-order -23 "$inducks_path_yesterday/$isv_subdir/$table.isv" "$inducks_path/$isv_subdir/$table.isv" > "$inducks_path/$isv_subdir/$table.removed.isv"
}

. /home/coa.properties

inducks_path=/home/inducks
inducks_path_yesterday=/home/inducks_$(date -d "yesterday 12:00 " '+%Y-%m-%d')
isv_subdir=isv
full_query_file=createtables_clean.sql
diff_query_file=insert_day_diff.sql
entrytitle_index_creation_query="ALTER TABLE inducks_entry ADD FULLTEXT INDEX entryTitleFullText(title);"

rm -rf ${inducks_path}
mkdir -p ${inducks_path}/${isv_subdir}

cd ${inducks_path}

wget http://coa.inducks.org/inducks/isv.7z && 7zr x isv.7z && rm isv.7z
for f in ${inducks_path}/${isv_subdir}/*.isv; do iconv -f utf-8 -t utf-8 -c "$f" > "$f.clean" && mv -f "$f.clean" "$f"; done # Ignore lines with invalid UTF-8 characters
mv ${inducks_path}/${isv_subdir}/createtables.sql ${inducks_path}

cp ${inducks_path}/createtables.sql ${inducks_path}/${full_query_file}

perl -0777 -i -pe 's%(CREATE TABLE (?:IF NOT EXISTS )?induckspriv[^;]+;)|([^\n]*induckspriv[^\n]*)%%gms' ${inducks_path}/${full_query_file} # Remove mentions of inducks_priv* tables
perl -0777 -i -pe "s%(# End of file)$%${entrytitle_index_creation_query}\n\n\1%gms" ${inducks_path}/${full_query_file} # Add full text index on entry titles

set +x
echo "mysql --user=root --password=xxxxxxxx -e 'CREATE DATABASE IF NOT EXISTS coa /*!40100 DEFAULT CHARACTER SET utf8 */;'" 1>&2
mysql --user=root --password=${DB_PASSWORD} -e 'CREATE DATABASE IF NOT EXISTS coa /*!40100 DEFAULT CHARACTER SET utf8 */;'

query_file_to_process=${full_query_file}

if [ -d "$inducks_path_yesterday" ]; then
  echo "Yesterday's data was archived, starting comparison with new data..."
  if isSameFileAsYesterday ${full_query_file}; then
    query_file_to_process=${diff_query_file}
    echo "Starting comparison with yesterday's archive"

    while read -r tableName
    do
      printf "%-40s%s" "Table $tableName"
      createFileWithAddedLinesSinceYesterdayForTable ${tableName}
      createFileWithRemovedLinesSinceYesterdayForTable ${tableName}

      if [ -s "$inducks_path/$isv_subdir/$tableName.removed.isv" ]; then
        printf "%-40s%s" "Data removed YES"
        printf "re-importing complete table\n"
        todays_diff+="TRUNCATE $tableName;\nLOAD DATA LOCAL INFILE \"./isv/$tableName.isv\" INTO TABLE $tableName FIELDS TERMINATED BY '^' IGNORE 1 LINES;\n\n"
      else
        printf "%-20s%s" "Data removed NO"
        if [ -s "$inducks_path/$isv_subdir/$tableName.added.isv" ]; then
          printf "%-20s%s" "Data added YES"
          printf "adding SQL data import command for the new data\n"
          todays_diff+="LOAD DATA LOCAL INFILE \"./isv/$tableName.added.isv\" INTO TABLE $tableName FIELDS TERMINATED BY '^' IGNORE 1 LINES;\n\n"
        else
          printf "%-20s%s" "Data added NO"
          printf "skipping table\n"
        fi
      fi
    done < <(cat ${inducks_path}/${full_query_file} | grep -Eo 'CREATE TABLE IF NOT EXISTS ([^ ]+)' | cut -d' ' -f6 | uniq | sort)

    echo -e ${todays_diff} > ${inducks_path}/${diff_query_file}
  else
    echo "The createtables script was modified, re-creating database"
  fi
else
  echo "No archive exists for yesterday's data, re-creating database"
fi

echo "mysql -v --user=root --password=xxxxxxxx --default_character_set utf8 coa --local_infile=1 < ${inducks_path}/${query_file_to_process}" 1>&2

begin=$(date +%s)
mysql -v --user=root --password=${DB_PASSWORD} --default_character_set utf8 coa --local_infile=1 < ${inducks_path}/${query_file_to_process}
end=$(date +%s) && echo $(expr $end - $begin)
