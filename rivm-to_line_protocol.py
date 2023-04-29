#!/usr/bin/env python3

# Adapted from https://github.com/tomru/cram-luftdaten.git

import os
import sys
import csv
from datetime import datetime, timedelta

def get_timestamp(timestr):
    """Converts CSV time value to a UTC timestamp in seconds"""
    naive_dt = datetime.strptime(timestr, "%Y-%m-%dT%H:%M:%S%z")
    utc = (naive_dt - datetime(1970, 1, 1, 0, 0, 0, 0, naive_dt.tzinfo)) / timedelta(seconds=1)
    return int(utc)

def rreplace(s, old, new, occurrence):
    li = s.rsplit(old, occurrence)
    return new.join(li)
 
NAME_MAP = {
    "OrigField": "renamedfield",
}

Station_Map = {
    "NL01484": "Rotterdam-Geulhaven",
    "NL01485": "Rotterdam-Hoogvliet",
    "NL01487": "Rotterdam-Pleinweg",
    "NL01488": "Rotterdam-Zwartewaalstraat",
    "NL01489": "Ridderkerk-A16",
    "NL01491": "Overschie-A13",
    "NL01492": "Rotterdam-Vasteland",
    "NL01493": "Rotterdam-Statenweg",
    "NL01494": "Schiedam-A.Arienstraat",
    "NL01495": "Maassluis-Kwartellaan",
    "NL01496": "Rotterdam-HvHolland",
    "NL01497": "Rotterdam-Maasvlakte",
    "NL01908": "Alblasserdam-Ruigenhil",
    "NL01912": "Ridderkerk-Voorweg",
    "NL01913": "Sluiskil-Stroodorpestraat",
    "NL10107": "Posterholt-Vlodropperweg",
    "NL10131": "Vredepeel-Vredeweg",
    "NL10133": "Wijnandsrade-Opfergeltstraat",
    "NL10136": "Heerlen-Looierstraat",
    "NL10138": "Heerlen-Jamboreepad",
    "NL10230": "Biest\ Houtakker-Biestsestraat",
    "NL10235": "Huijbergen-Vennekenstraat",
    "NL10236": "Eindhoven-Genovevalaan",
    "NL10237": "Eindhoven-Noordbrabantlaan",
    "NL10240": "Breda-Tilburgseweg",
    "NL10241": "Breda-Bastenakenstraat",
    "NL10246": "Fijnaart-Zwingelspaansedijk",
    "NL10247": "Veldhoven-Europalaan",
    "NL10248": "Nistelrode-Gagelstraat",
    "NL10301": "Zierikzee-Lange\ Slikweg",
    "NL10318": "Philippine-Stelleweg",
    "NL10404": "Den\ Haag-Rebecquestraat",
    "NL10418": "Rotterdam-Schiedamsevest",
    "NL10437": "Westmaas-Groeneweg",
    "NL10442": "Dordrecht-Bamendaweg",
    "NL10444": "De\ Zilk-Vogelaarsdreef",
    "NL10445": "Den\ Haag-Amsterdamse\ Veerkade",
    "NL10446": "Den\ Haag-Bleriotlaan",
    "NL10449": "Vlaardingen-Riouwlaan",
    "NL10450": "Den\ Haag-Neherkade",
    "NL10538": "Wieringerwerf-Medemblikkerweg",
    "NL10550": "Haarlem-Schipholweg",
    "NL10617": "Biddinghuizen-Kuilweg",
    "NL10633": "Zegveld-Oude\ Meije",
    "NL10636": "Utrecht-Kardinaal\ de\ Jongweg",
    "NL10639": "Utrecht-Constant\ Erzeijstraat",
    "NL10641": "Breukelen-A2",
    "NL10643": "Utrecht-Griftpark",
    "NL10644": "Cabauw-Wielsekade",
    "NL10722": "Eibergen-Lintveldseweg",
    "NL10738": "Wekerom-Riemterdijk",
    "NL10741": "Nijmegen-Graafseweg",
    "NL10742": "Nijmegen-Ruyterstraat",
    "NL10807": "Hellendoorn-Luttenbergerweg",
    "NL10818": "Barsbeek-De\ Veenen",
    "NL10821": "Enschede-Winkelshorst",
    "NL10918": "Balk-Trophornsterweg",
    "NL10929": "Valthermond-Noorderdiep",
    "NL10934": "Kollumerwaard-Hooge\ Zuidwal",
    "NL10937": "Groningen-Europaweg",
    "NL10938": "Groningen-Nijensteinheerd",
    "NL49002": "Amsterdam-Haarlemmerweg",
    "NL49003": "Amsterdam-Nieuwendammerdijk",
    "NL49007": "Amsterdam-Einsteinweg",
    "NL49012": "Amsterdam-Van\ Diemenstraat",
    "NL49014": "Amsterdam-Vondelpark",
    "NL49016": "Amsterdam-Westerpark",
    "NL49017": "Amsterdam-Stadhouderskade",
    "NL49019": "Amsterdam-Oude\ Schans",
    "NL49020": "Amsterdam-Jan\ van\ Galenstraat",
    "NL49021": "Amsterdam-Kantershof",
    "NL49022": "Amsterdam-Ookmeer",
    "NL49546": "Zaanstad-Hemkade",
    "NL49551": "IJmuiden-Kanaalstraat",
    "NL49553": "Wijk\ aan\ Zee-De\ Banjaert",
    "NL49556": "De\ Rijp-Oostdijkje",
    "NL49557": "Wijk\ aan\ Zee-Bosweg",
    "NL49561": "Badhoevedorp-Sloterweg",
    "NL49564": "Hoofddorp-Hoofdweg",
    "NL49565": "Oude\ Meer-Aalsmeerderdijk",
    "NL49570": "Beverwijk-Creutzberglaan",
    "NL49572": "Velsen-Staalstraat",
    "NL49573": "Velsen-Reyndersweg",
    "NL49701": "Zaandam-Wagenschotpad",
    "NL49703": "Spaarnwoude-Machineweg",
    "NL49704": "Zaanstad-Hoogtij",
    "NL50002": "Geleen-Vouershof",
    "NL50003": "Geleen-Asterstraat",
    "NL50004": "Maastricht-A2-Nassaulaan",
    "NL50006": "Horst_a/d_Maas-Hoogheide",
    "NL50007": "Maastricht-Hoge_Fronten",
    "NL50009": "Maastricht-A2-Kasteel_Hillenraadweg",
    "NL50010": "Maastricht-A2-Philipsweg",
    "NL53001": "Ossendrecht-Burgemeester\ Voetenstraat",
    "NL53004": "Moerdijk-Julianastraat",
    "NL53015": "Klundert-Kerkweg",
    "NL53016": "Zevenbergen-Galgenweg",
    "NL53020": "Strijensas\ Buitendijk",
    "NL54004": "Arnhem\ Velperbroek",
    "NL54010": "Arnhem\ GelreDome",
}
Sample = {
  "station_number": "NL10247",
  "value": 11.84,
  "timestamp_measured": "2020-05-08T22:00:00+00:00",
  "formula": "NO2"
}

fieldnames = ['station_number', 'value', 'timestamp_measured', 'formula']
READER = csv.DictReader(sys.stdin, fieldnames=fieldnames, delimiter=",")
for row in READER:

    measurements = []

    for header, value in row.items():
        if header == "formula" or not value:
            continue
        if header == "value":
            measurements.append("{0}={1}".format(NAME_MAP.get(header, header), value))
        else:
            measurements.append("{0}={1}".format(NAME_MAP.get(header, header), '"' + value + '"'))

    values = {
        "station": Station_Map.get(row["station_number"], row["station_number"]),
        "measurements": ",".join(measurements),
        "time": get_timestamp(rreplace(row["timestamp_measured"],':','',1)),
        "formula": row["formula"]
    }

    print("{station},formula={formula} {measurements} {time}".format(**values))
