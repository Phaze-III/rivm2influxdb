#!/bin/sh

Sensors="${SAMENMETEN_SENSORID:-LTD_xxxxx}"  # Set this to your own Sensor ID(s)
DataDir="${SAMENMETEN_DATADIR:-.}"

export INFLUXDB_DATABASE="${INFLUXDB_DATABASE:-samenmeten}"
export INFLUXDB_HOST="${INFLUXDB_HOST:-localhost}"
export INFLUXDB_PORT="${INFLUXDB_PORT:-8086}"
export INFLUXDB_PRECISION="${INFLUXDB_PRECISION:-s}"

# Set begin and end date to yesterday
if date --version >/dev/null 2>&1
then
   # GNU date
   Day=$(date -d "-1 day" "+%F")
else
   # BSD date
   Day=$(date -j -v-1d "+%F")
fi

# Day='2020-05-14' # For testing

Store='pm*' # Default pattern for Formula's to store (PM data only)
if [ $# -ne 0 ]
then
   while [ $# -ne 0 ]
   do
      case $1 in
      -h|--history)
         # Get all historical data up until ${Day}
         DateOperator="le"
         FileFill="_history"
         ;;
      -a|--all)
         # Send all measurements (not only PM*) to database
         Store='*'
         ;;
      -n|--none)
         # Do not send any measurement to database
         Store='+none+'
         ;;
      esac
      shift
   done
fi

APIURI='https://api-samenmeten.rivm.nl/v1.0'
ODATAFilter="?\$filter=date%28phenomenonTime%29+${DateOperator:-eq}+date%28%27${Day}%27%29"

for Sensor in ${Sensors}
do
   DatastreamsTmpFile="${DataDir}/${Day}_Datastreams_${Sensor}${FileFill}_$(date +%s).csv"
   DatastreamsLink=$(curl -sS "${APIURI}/Things?\$filter=startswith(name,%27${Sensor}%27)" \
                      | jq -r '.value[]."Datastreams@iot.navigationLink"')
   
   curl -sS "${DatastreamsLink}" \
      | jq -r ' .value[] | [.description, ."@iot.id", ."Observations@iot.navigationLink"] | @csv' \
      > "${DatastreamsTmpFile}"
   
   IFS=,
   cat ${DatastreamsTmpFile} | tr -d '<>|"' | \
   while read Description StreamID ObservationLink
   do
      Formula="${Description##${Sensor}-?-}"
      APIEndPoint="Datastreams(${DatastreamID})/Observations"
      Page=1
      APICall="${ObservationLink}${ODATAFilter}"
      Tries=1
   
      while [ -n "${APICall}" ]
      do
         jsonFile="${DataDir}/${Day}_${Description}${FileFill}_p$(printf %03d ${Page}).json"
         csvFile="${DataDir}/${Day}_${Description}${FileFill}_p$(printf %03d ${Page}).csv"
         ResultCode=$(curl -sS -w "%{http_code}" --location "${APICall}" -o "${jsonFile}")
         if [ "${ResultCode}" -ne 200 ] 
         then
            if [ ${Tries} -lt 3 ]
            then
               echo "ERROR: ${Day} ${Description} page ${Page} try ${Tries}: ${ResultCode}, sleeping..." >&2
               sleep 60
               Tries=$((${Tries} + 1))
               continue
            else
               echo "ERROR: Failed to fetch ${Day} (${DateOperator:-eq}) ${Description}, page ${Page} after ${Tries} tries, moving on..." >&2
               echo "ERROR: ${APICall}" >&2
               break
            fi
         else
            Tries=1
         fi
         NextLink=$(jq -r '."@iot.nextLink" // "" ' "${jsonFile}")
         APICall=${NextLink}
         Page=$((${Page} + 1))
         case ${Formula} in
         ${Store})
            cat "${jsonFile}" \
              | jq -r '.value[]|flatten|@csv' \
              | awk -F, -v OFS=, -v Sensor=${Sensor} -v Formula=${Formula} \
                   '{if (length($4) > 0) {gsub(/.000Z/, "+00:00", $3); print Sensor, $4, $3, toupper(Formula)}}' \
              > "${csvFile}"
            cat "${csvFile}" | rivm-to_line_protocol.py | to_influx_db.sh 
            ;;
         esac
      done
   done
   
   rm -f ${DatastreamsTmpFile}
done
