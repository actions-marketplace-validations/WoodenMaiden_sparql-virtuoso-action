#!/usr/bin/env bash

set -e

QUERY='SPARQL\n'
GRAPH=''

if [ -e $1 ]
then
    echo "Reading file $1..."
    while IFS= read -r line; do
        entryGraph=$(echo $line | awk -F ', ' '{print $2}')
        entry=$(echo $line | awk -F ', ' '{print $1}')
        if [ -z "$entryGraph" ]
        then 
            GRAPH=$entry
            QUERY=$QUERY"create graph <$GRAPH>;\n"
        else
            if [ -z "$GRAPH" ]
            then
                s=$(echo $line | awk -F ', ' '{print $1}')
                p=$(echo $line | awk -F ', ' '{print $2}')
                o=$(echo $line | awk -F ', ' '{print $3}')

                if [ -z "$(echo $o | grep -Eo '[a-zA-Z0-9]+://[a-zA-Z0-9./?=_%:-]*')" ] 
                then 
                    QUERY=$QUERY"INSERT DATA { <$s> <$p> '$o' };\n"
                else 
                    QUERY=$QUERY"INSERT DATA { <$s> <$p> <$o> };\n"
                fi
            else 
                s=$(echo $line | awk -F ', ' '{print $1}')
                p=$(echo $line | awk -F ', ' '{print $2}')
                o=$(echo $line | awk -F ', ' '{print $3}')

                if [ -z "$(echo $o | grep -Eo '[a-zA-Z0-9]+://[a-zA-Z0-9./?=_%:-]*')" ] 
                then 
                    QUERY=$QUERY"INSERT DATA { GRAPH <$GRAPH> { <$s> <$p> '$o' } };\n"
                else 
                    QUERY=$QUERY"INSERT DATA { GRAPH <$GRAPH> { <$s> <$p> <$o> } };\n"
                fi
            fi
        fi
    done < $1
    QUERY=$QUERY"EXIT;\nshutdown;\n"
    echo "Finished reading files, now injecting query..."
    printf  "printf \"$QUERY\" | isql -P \"$DBA_PASSWORD\" > /dev/null && exit" | docker exec virtuoso sh 
    
    echo "Query sucessfully injected!"
else 
    echo 'Could not read file'
fi