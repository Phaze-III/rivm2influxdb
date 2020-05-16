#!/bin/sh

DataDir="${RIVM_DATADIR:-.}"

export INFLUXDB_DATABASE="${INFLUXDB_DATABASE:-rivm}"
export INFLUXDB_HOST="${INFLUXDB_HOST:-localhost}"
export INFLUXDB_PORT="${INFLUXDB_PORT:-8086}"
export INFLUXDB_PRECISION="${INFLUXDB_PRECISION:-s}"

API='https://api.luchtmeetnet.nl/open_api'
EndPoint='measurements'

StartDay='2020-05-14'
StopDay='2020-05-15'

setdates () {
   if date --version >/dev/null 2>&1
   then
      # GNU date
      case $2 in
      next)
         Start="$(date -d "${1}T00:00:00 next day" +%FT%T%z)" ;;
      prev)
         Start="$(date -d "${1}T00:00:00 previous day" +%FT%T%z)" ;;
      *)
         Start="$(date -d "${1}T00:00:00" +%FT%T%z)" ;;
      esac
      End=$(date -d "@$(($(date -d "${Start} next day" +%s) - 1))" +%FT%T%z)
      Day="$(date -d ${Start} +%F)"
   else
      # BSD date
      case $2 in
      next)
         Start="$(date -v+1d -j -f '%FT%T' ${1}T00:00:00 +%FT%T%z)" ;;
      prev)
         Start="$(date -v-1d -j -f '%FT%T' ${1}T00:00:00 +%FT%T%z)" ;;
      *)
         Start="$(date -j -f '%FT%T' ${1}T00:00:00 +%FT%T%z)" ;;
      esac
      End=$(date -j -v-1S -f %s $(date -j -v+1d -f '%FT%T%z' ${Start} +%s) +%FT%T%z)
      Day="$(date -j -f '%FT%T%z' ${Start} +%F)"
   fi
}

setdates ${StartDay}

while [ "${Day}" != "${StopDay}" ]
do
   Page=1
   NextPage=${Page}

   while [ ${Page} -le ${NextPage} ]
   do
      jsonFile="${DataDir}/rivm-data-${Day}-page$(printf %03d ${Page}).json"
      curl -sS --location \
        "${API}/${EndPoint}?page=${Page}&station_number=&formula=&order_by=timestamp_measured&order_direction=asc&start=${Start}&end=${End}" \
        > ${jsonFile}
      NextPage=$(jq -r '.pagination.next_page' "${jsonFile}")
      Page=$((${Page} + 1))
      cat "${jsonFile}" | jq -r '.data[]|flatten|@csv' | rivm-to_line_protocol.py | to_influx_db.sh
   done

   setdates ${Day} next
done
