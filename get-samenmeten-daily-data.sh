#!/bin/sh

Sensor="${RIVM_SENSORID:-LTD_xxxxx}"  # Set this to your own Sensor ID
DataDir="${RIVM_DATADIR:-.}"

export INFLUXDB_DATABASE="${INFLUXDB_DATABASE:-rivm}"
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
         ;;
      -a|--all)
         # Send all measurements (not only PM*) to database
         Store='*'
         ;;
      esac
      shift
   done
fi

APIURI='https://api-samenmeten.rivm.nl/v1.0'
ODATAFilter="?\$filter=date%28phenomenonTime%29+${DateOperator:-eq}+date%28%27${Day}%27%29"

DatastreamsTmpFile="${DataDir}/${Day}_Datastreams_${Sensor}_$(date +%s).csv"
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

   while [ -n "${APICall}" ]
   do
      jsonFile="${DataDir}/${Day}_${Description}_p$(printf %03d ${Page}).json"
      csvFile="${DataDir}/${Day}_${Description}_p$(printf %03d ${Page}).csv"
      curl -sS --location "${APICall}" > "${jsonFile}"
      NextLink=$(jq -r '."@iot.nextLink" // "" ' "${jsonFile}")
      APICall=${NextLink}
      Page=$((${Page} + 1))
      case ${Formula} in
      ${Store})
         cat "${jsonFile}" \
           | jq -r '.value[]|flatten|@csv' \
           | awk -F, -v OFS=, -v Sensor=${Sensor} -v Formula=${Formula} \
                '{if (length($4) > 0) { gsub(/.000Z/, "+00:00", $3 ) ;print Sensor,$4, $3, toupper(Formula) }}' \
           > "${csvFile}"
         cat "${csvFile}" | rivm-to_line_protocol.py | to_influx_db.sh 
         ;;
      esac
   done
done

rm -f ${DatastreamsTmpFile}
