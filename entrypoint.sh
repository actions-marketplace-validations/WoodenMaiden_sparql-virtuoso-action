#!/usr/bin/env bash

set -e 

export DBA_PASSWORD="$1"
export DAV_PASSWORD="$2"


docker run -e DBA_PASSWORD="$DBA_PASSWORD" \
    -e DAV_PASSWORD="$DAV_PASSWORD" \
    -v "$(pwd)":/database \
    --name virtuoso \
    openlink/virtuoso-opensource-7 \
    /opt/virtuoso-opensource/bin/virtuoso-t -f +checkpoint-only +pwdold dba +pwddba "$DBA_PASSWORD"

docker commit virtuoso database:latest # in order to keep changes and run a different CMD
docker rm -f virtuoso

if [ -n "$3" ]
then
   ./populate.sh "$3"
fi

echo "Launching the instance"
docker run -e DBA_PASSWORD="$DBA_PASSWORD" \
    -e DAV_PASSWORD="$DAV_PASSWORD" \
    -v "$(pwd)":/database -d \
    --name virtuoso \
    -p 1111:1111 \
    -p 8890:8890 \
    database:latest \
    /opt/virtuoso-opensource/bin/virtuoso-t +foreground