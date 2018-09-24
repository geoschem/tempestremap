#!/bin/bash

# Script for creating regional tile files using tempestremap
#
# Lizzie Lundgren, 9/24/18
# This script is based on earlier scripts by Sebastian Eastham, Jiawei Zhuang, 
# and myself.

if [[ ! -n $NETCDF_HOME ]]; then
   echo "Could not establish location of NetCDF"
   exit 2
fi

#===== CONFIGURABLE INPUT PARMAMETERS ====================================

# -- Set identifying name --
# This will get printed at the end, or will get written to log if you make one
inventory='APEI'

# -- Set source lat/lon grid size and targed cubed sphere resolution --
# Always create tile files one at a time for 24, 48, 90, 180, and 360
nLon=1250
nLat=700
nC=24

# -- Set regional lat/lon grid parameters --
# Use bounds and grid spacing found in the source lat/lon data file
lonstart=-174.95
lonend=-50.05
latstart=15.05
latend=84.95
deltalon=0.1
deltalat=0.1
 
# -- Additional options --
isL2C=true    # Get lat/lon to cubed sphere mapping
isC2L=false   # Get cubed sphere to lat/lon mapping
isGMAO=true   # Use 10 degree offset? Always set to true for GCHP tile files.
MAPLName=true # Use the MAPL conventions to name the file?

# -- Set output destination folder --
outdest=$(pwd -P)/TileFiles # Local output destination

# -- Note on validation --
# lat/lon -> cubed sphere tile file can be inspected using any software 
# that can read netcdf. To validate, do the following:
# 1. Check that the size in the output filename (# lons and # lats) matches 
#      those in the original file.
# 2. Check that the min/max/step of variable xc_a is equal to the longitudes
#      of those in the orginal file plus 190 degrees. The shift is due to 
#      a different longitude reference point in Tempest.
# 3. Check that the min/max/step of variable yc_a match the latitudes of the 
#      original file. 

#===== END OF CONFIGURABLE INPUTS ========================================
# Not necessary to change anything beyond this point.

# -- Calculate values to pass to tempest --
# NOTE: This applies a 180 longitude shift and also half a step size to both
# lat and lon bounds.
lona=$(echo $lonstart $deltalon | awk '{ printf "%f", $1 + 180 - $2/2 }')
lonb=$(echo $lonend $deltalon | awk '{ printf "%f", $1 + 180 + $2/2 }')
lata=$(echo $latstart $deltalat | awk '{ printf "%f", $1 - $2/2 }')
latb=$(echo $latend $deltalat | awk '{ printf "%f", $1 + $2/2 }')

# -- Make output directory if it does not already exist --
mkdir -p ${outdest}

# -- Create strings --

# grid bounds
region=' --lon_begin '+${lona}+' --lon_end '+${lonb}+' --lat_begin '+${lata}+' --lat_end '+${latb}+' '

# grid type string and GMAO offset option
tempestopt=''
if $isGMAO;then
    gridtype+='_GMAO'
    tempestopt+=' --GMAOoffset '
else
    gridtype+='_NoOffset'
fi

# Generate a MAPL-style name for the lat-lon and CS grids
printf -v MAPLGridLL "%s%04dx%s%04d" 'UU' $nLon 'UU' $nLat
printf -v MAPLGridCS "CF%04dx6C" $nC

# output file name
llStr=lon${nLon}_lat${nLat} 
out_ll=${llStr}_${gridtype}.g #grid type belongs to RLL mesh
out_cs=c${nC}.g
out_ov=${llStr}-and-c${nC}.g #overlap mesh. can be used for both C2L and L2C

# -- Run Tempest from the bin directory --

cd ./bin

./GenerateRLLMesh --lon ${nLon} --lat ${nLat} --file ${out_ll} ${tempestopt} ${region} #all options applied to RLL mesh
./GenerateCSMesh --res ${nC} --alt --file ${out_cs}
./GenerateOverlapMesh --a ${out_ll} --b ${out_cs} --out ${out_ov}

if $isC2L;then
    if $MAPLName;then
       out_c2l=${MAPLGridCS}_${MAPLGridLL}.nc
    else
       out_c2l=c${nC}-to-${llStr}_MAP_${gridtype}.nc
    fi
    out_c2l=c${nC}-to-${llStr}_MAP_${gridtype}.nc
    ./GenerateOfflineMap --in_mesh ${out_cs} --out_mesh ${out_ll} --ov_mesh ${out_ov} --in_np 1 --out_map ${out_c2l}
    mv ${out_c2l} ${outdest}
fi

if $isL2C;then
    if $MAPLName;then
       out_l2c=${MAPLGridLL}_${MAPLGridCS}.nc
    else
       out_l2c=${llStr}-to-c${nC}_MAP_${gridtype}.nc
    fi
    ./GenerateOfflineMap --in_mesh ${out_ll} --out_mesh ${out_cs} --ov_mesh ${out_ov} --in_np 1 --out_map ${out_l2c}
    mv ${out_l2c} ${outdest}
fi

rm *.g # remove intermediate files for clarity

echo 'Inventory name: '  $inventory
echo 'Source latxlon res: ' $nLat  'x'  $nLon
echo 'Target cubed sphere res: '  $nC
echo 'Source file longitudes (start:step:stop): '  $lonstart ':' $lonend ':' $deltalon
echo 'Source file latitudes (start:step:stop): '  $latstart ':' $latend ':' $deltalat
echo 'GMAO longitude offset on: '  $isGMAO
echo 'Output folder: '  $outdest
echo 'Output cs->lat/lon tile file: '  $out_l2c
