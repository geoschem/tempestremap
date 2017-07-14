#!/bin/bash

# Script for running Tempest. 
# Modified from /n/home08/elundgren/GCHP/tools/Tempest/runTempest.sh
# Jiawei Zhuang 2016/12
# Edited by S. D. Eastham (2017-03-10)

if [[ $# -ne 5 ]]; then
   echo "Need exactly 5 arguments:"
   echo " => Number of cells (longitude)"
   echo " => Number of cells (latitude)"
   echo " => Number of cells per cube side"
   echo " => Is the longitude dimension dateline-centered (true/false)"
   echo " => Is the latitude dimension pole-centered (true/false)"
   exit 1
fi

if [[ ! -n $NETCDF_HOME ]]; then
   echo "Could not establish location of NetCDF"
   exit 2
fi

# --input parameters--
# switches for regridding types. Can use both!
isC2L=false
isL2C=true
# grid resolution
nLon=$1
nLat=$2
nC=$3
# additional
isDC=$4 # change from DE to DC?
isPC=$5 # change from PE to PC?
isGMAO=true # use 10 degree offset?
MAPLName=true # Use the MAPL conventions to name the file?

# --output directory--
outdest=$(pwd -P)/TileFiles
# make output directory if it does not already exist
mkdir -p ${outdest}

# --tempest directory--
tempestdir='.'

# -------------------------------------
#   the followings are seldom changed
# -------------------------------------

# --create strings--

# grid type string and tempest additional options
if $isDC;then
    gridtypeD='DC'
    tempestopt=' --lonshift '
else
    gridtypeD='DE'
    tempestopt=' '
fi
if $isPC;then
    gridtypeP='PC'
    tempestopt+=' --halfpole '
else
    gridtypeP='PE'
fi
if $isGMAO;then
    gridtypeG='_GMAO'
    tempestopt+=' --GMAOoffset '
else
    gridtypeG='_NoOffset'
fi

gridtype=$gridtypeD$gridtypeP$gridtypeG

# Generate a MAPL-style name for the lat-lon and CS grids
printf -v MAPLGridLL "%s%04dx%s%04d" $gridtypeD $nLon $gridtypeP $nLat
printf -v MAPLGridCS "CF%04dx6C" $nC

# output file name
llStr=lon${nLon}_lat${nLat} 
out_ll=${llStr}_${gridtype}.g #grid type belongs to RLL mesh
out_cs=c${nC}.g
out_ov=${llStr}-and-c${nC}.g #overlap mesh. can be used for both C2L and L2C

# --Run Tempest--

cd $tempestdir/bin

./GenerateRLLMesh --lon ${nLon} --lat ${nLat} --file ${out_ll} ${tempestopt} #all options applied to RLL mesh
./GenerateCSMesh --res ${nC} --alt --file ${out_cs}
./GenerateOverlapMesh --a ${out_ll} --b ${out_cs} --out ${out_ov}

if $isC2L;then
    if $MAPLName;then
       out_c2l=${MAPLGridCS}_${MAPLGridLL}.nc
    else
       out_c2l=c${nC}-to-${llStr}_MAP_${gridtype}.nc
    fi
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

echo 'using addtional option:' ${tempestopt}
