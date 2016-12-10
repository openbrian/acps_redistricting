#!/bin/bash

osm2pgrouting  \
   -f extract.osm  \
   --host $HOST  \
   --dbname $DBNAME  \
   --schema $SCHEMA  \
   --addnodes

