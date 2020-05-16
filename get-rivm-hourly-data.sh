#!/bin/sh

DataDir="${RIVM_DATADIR:-.}"

export INFLUXDB_DATABASE="${INFLUXDB_DATABASE:-rivm}"
export INFLUXDB_HOST="${INFLUXDB_HOST:-localhost}"
export INFLUXDB_PORT="${INFLUXDB_PORT:-8086}"
export INFLUXDB_PRECISION="${INFLUXDB_PRECISION:-s}"

APIURI='https://api.luchtmeetnet.nl/open_api'
APIEndPoint='measurements'

if date --version >/dev/null 2>&1
then
   # GNU date
   StartHour="$(date -d "-4 hour" +%H)"
   StopHour="$(date -d "-1 hour" +%H)"
   StartDay="$(date -d "-4 hour" +%F)"
   StopDay="$(date -d "-1 hour" +%F)"
   Start="$(date -d ${StartDay}T${StartHour}:00:00 +%FT%T%z)"
   End="$(date -d ${StopDay}T${StopHour}:00:00 +%FT%T%z)"
else
   # BSD date
   StartHour="$(date -j -v-4H +%H)"
   StopHour="$(date -j -v-1H +%H)"
   StartDay="$(date -j -v-4H +%F)"
   StopDay="$(date -j -v-1H +%F)"
   Start="$(date -j -f '%FT%T' ${StartDay}T${StartHour}:00:00 +%FT%T%z)"
   End="$(date -j -f '%FT%T' ${StopDay}T${StopHour}:00:00 +%FT%T%z)"
fi


Page=1
NextPage=${Page}

while [ ${Page} -le ${NextPage} ]
do
   jsonFile="${DataDir}/rivm-data-${StartDay}_${StartHour}-${StopDay}_${StopHour}_page$(printf %03d ${Page}).json"
   curl -sS --location \
     "${APIURI}/${APIEndPoint}?page=${Page}&station_number=&formula=&order_by=timestamp_measured&order_direction=asc&start=${Start}&end=${End}" \
     > "${jsonFile}"
   NextPage=$(jq -r '.pagination.next_page' "${jsonFile}")
   if [ ${NextPage} -eq 0 ]
   then
      echo "Error: No data for ${Start} to ${End}" >&2
      rm "${jsonFile}"
      exit 1
   fi
   cat "${jsonFile}" | jq -r '.data[]|flatten|@csv' | rivm-to_line_protocol.py | to_influx_db.sh
   Page=$((${Page} + 1))
done
