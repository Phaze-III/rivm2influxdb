# rivm2influxdb
Fetch various public RIVM pollution data and convert to influx line protocol

# Requirements

Tested on Linux and BSD (Mac OSX and FreeBSD)

# Dependencies

* python3 minimal
* curl (https://curl.haxx.se/)
* jq JSON-parser (https://stedolan.github.io/jq/)

# Usage

* Create a new InfluxDB with 'create database rivm'
* Modify the DataDir and INFLUXDB-settings in get-\*.sh as needed
* Modify the StartDay and StopDay-settings in get-rivm-data-per-day.sh 
  and run the script to fetch historical data from all stations
* Run get-rivm-hourly-data.sh to fetch the last 4 hours of data from all
  stations in your hourly cron (not all stations are updated within an
  hour so to be safe 3 hours of data is refetched, duplicates are handled
  by InfluxDB)

If you have your own particle dust sensor registered on one of the
community projects (e.g. Luftdaten) you can use the
get-samenmeten-daily-data.sh script to fetch the hourly averages,
including 'calibrated' PM data for your sensor.

* Go to https://samenmeten.rivm.nl/dataportaal/ and locate your sensor
  on the map
* Get the sensor ID by hoovering over the sensor
* Put the ID in get-samenmeten-daily-data.sh

The get-samenmeten-daily-data.sh can be run from your daily cron. Data
is made available on a daily basis in the morning of the next day (after
6 AM local Dutch time appears to be fine). The script fetches all
available data from 'yesterday' from your sensor but only sends the
PM-data (raw and calibrated) to InfluxDB.

# Additional info

* https://api-docs.luchtmeetnet.nl/?version=latest
* https://www.samenmetenaanluchtkwaliteit.nl/dataportaal/api-application-programming-interface
* https://www.samenmetenaanluchtkwaliteit.nl/dataportaal/kalibratie-van-fijnstofsensoren

# Acknowledgements

* Basics and Python-code adapted from https://github.com/tomru/cram-luftdaten
