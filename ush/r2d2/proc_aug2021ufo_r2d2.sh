#!/bin/bash
dataroot=/work2/noaa/da/cmartin/UFO_eval/data/aug2021_ufo_eval
iodaconv="NO"
satbiasconv="YES"
r2d2store_obs="NO"
r2d2store_bc="YES"
r2d2store_bkg="NO"
startdate=2021080100
enddate=2021080718
dump="gdas"
HOMEgdas=/work2/noaa/da/cmartin/GDASApp/work/GDASApp
machine="orion"

#---------------------------------------------------------------
# do not modify below here
#---------------------------------------------------------------

# load runtime env
#---------------------------------------------------------------
module purge
module use $HOMEgdas/modulefiles
module load GDAS/$machine

# run ioda converters
#---------------------------------------------------------------
convertpy=$HOMEgdas/build/bin/proc_gsi_ncdiag.py
combinepy=$HOMEgdas/build/bin/combine_obsspace.py
export PYTHONPATH=$PYTHONPATH:$HOMEgdas/build/lib/python3.7/pyioda

if [ $iodaconv = "YES" ]; then
  nowdate=$startdate
  while test $nowdate -le $enddate ; do
    echo "Converting obs to IODA for $nowdate"
    nowpdy=${nowdate::8}; nowcyc=${nowdate:8}
    diagdir=$dataroot/${dump}.$nowpdy/$nowcyc/atmos/
    cd $diagdir
    mkdir -p $diagdir/ioda
    $convertpy -o $diagdir/ioda $diagdir/diags
    $combinepy -i $diagdir/ioda/sfc_*.nc4 -o $diagdir/ioda/sfc_obs_"$nowdate".nc4
    $combinepy -i $diagdir/ioda/sfcship_*.nc4 -o $diagdir/ioda/sfcship_obs_"$nowdate".nc4
    $combinepy -i $diagdir/ioda/sondes_*.nc4 -o $diagdir/ioda/sondes_obs_"$nowdate".nc4
    $combinepy -i $diagdir/ioda/aircraft_*.nc4 -o $diagdir/ioda/aircraft_obs_"$nowdate".nc4
    nowdate=$(date -d "$nowpdy $nowcyc + 6 hour" +%Y%m%d%H)
  done
fi

# run satbias converters
#---------------------------------------------------------------
satbiaspy=$HOMEgdas/ush/run_satbias_conv.py
if [ $satbiasconv = "YES" ]; then
  # python script runs over all period
  nowdate=$startdate
  nowpdy=${nowdate::8}; nowcyc=${nowdate:8}
  prevdate=$(date -d "$nowpdy $nowcyc - 6 hour" +%Y-%m-%dT%H)
  lastpdy=${enddate::8}; lastcyc=${enddate:8}
  lastprevdate=$(date -d "$lastpdy $lastcyc - 6 hour" +%Y-%m-%dT%H)
  # create YAML file
  cd $dataroot
  cat > $dataroot/run_satbias_conv.yaml << EOF
start time: $prevdate:00:00Z
end time: $lastprevdate:00:00Z
assim_freq: 6
gsi_bc_root: $dataroot
ufo_bc_root: $dataroot/satbias
work_root: $dataroot/work
satbias2ioda: $HOMEgdas/build/bin/satbias2ioda.x
dump: $dump
EOF
  $satbiaspy --config $dataroot/run_satbias_conv.yaml
fi

# store with r2d2
#---------------------------------------------------------------
r2d2storepy=$HOMEgdas/ush/r2d2/r2d2_store.py
export PYTHONPATH=$PYTHONPATH:$HOMEgdas/ush

if [ $r2d2store_obs = "YES" ]; then
  cd $dataroot
  nowpdy=${startdate::8}; nowcyc=${startdate:8}
  firstdate=$(date -d "$nowpdy $nowcyc" +%Y-%m-%dT%H)
  nowpdy=${enddate::8}; nowcyc=${enddate:8}
  lastdate=$(date -d "$nowpdy $nowcyc" +%Y-%m-%dT%H)
  cat > $dataroot/r2d2_store_obs.yaml << EOF
start: ${firstdate}:00:00Z
end: ${lastdate}:00:00Z
step: PT6H
source_dir: $dataroot
source_file_fmt: '{source_dir}/{dump}.{year}{month}{day}/{hour}/atmos/ioda/{obs_type}_obs_{year}{month}{day}{hour}.nc4'
type: ob
database: shared
provider: ncdiag
experiment: oper_$dump
obs_types:
  - aircraft
  - amsua_metop-a
  - amsua_metop-b
  - amsua_metop-c
  - amsua_n15
  - amsua_n18
  - amsua_n19
  - atms_n20
  - atms_npp
  - avhrr3_metop-a
  - avhrr3_n18
  - cris-fsr_n20
  - cris-fsr_npp
  - gome_metop-a
  - gome_metop-b
  - hirs4_metop-a
  - hirs4_n19
  - iasi_metop-a
  - iasi_metop-b
  - mhs_metop-a
  - mhs_metop-b
  - mhs_metop-c
  - mhs_n19
  - omi_aura
  - ompsnp_npp
  - ompstc8_npp
  - rass_tv
  #- saphir_meghat
  - satwind
  - sbuv2_n19
  - scatwind
  - seviri_m08
  - seviri_m11
  - sfc
  - sfcship
  - sondes
  - ssmis_f17
  - ssmis_f18
  - sst
  - vadwind
  #- windprof
EOF
  $r2d2storepy --config $dataroot/r2d2_store_obs.yaml
fi

if [ $r2d2store_bc = "YES" ]; then
  cd $dataroot
  nowpdy=${startdate::8}; nowcyc=${startdate:8}
  firstdate=$(date -d "$nowpdy $nowcyc - 6 hour" +%Y-%m-%dT%H)
  nowpdy=${enddate::8}; nowcyc=${enddate:8}
  lastdate=$(date -d "$nowpdy $nowcyc - 6 hour" +%Y-%m-%dT%H)
  cat > $dataroot/r2d2_store_satbias.yaml << EOF
start: ${firstdate}:00:00Z
end: ${lastdate}:00:00Z
step: PT6H
source_dir: $dataroot
source_file_fmt: '{source_dir}/satbias/{dump}.{year}{month}{day}/{hour}/atmos/{obs_type}_satbias.nc4'
type: bc
database: shared
provider: gsi
file_type: satbias
experiment: oper_$dump
obs_types:
  - aircraft
  - amsua_metop-a
  - amsua_metop-b
  - amsua_metop-c
  - amsua_n15
  - amsua_n18
  - amsua_n19
  - atms_n20
  - atms_npp
  - avhrr3_metop-a
  - avhrr3_n18
  - cris-fsr_n20
  - cris-fsr_npp
  - gome_metop-a
  - gome_metop-b
  - hirs4_metop-a
  - hirs4_n19
  - iasi_metop-a
  - iasi_metop-b
  - mhs_metop-a
  - mhs_metop-b
  - mhs_metop-c
  - mhs_n19
  - omi_aura
  - ompsnp_npp
  - ompstc8_npp
  - rass_tv
  #- saphir_meghat
  - satwind
  - sbuv2_n19
  - scatwind
  - seviri_m08
  - seviri_m11
  - sfc
  - sfcship
  - sondes
  - ssmis_f17
  - ssmis_f18
  - sst
  - vadwind
  #- windprof
EOF
  $r2d2storepy --config $dataroot/r2d2_store_satbias.yaml
  cat > $dataroot/r2d2_store_tlapse.yaml << EOF
start: ${firstdate}:00:00Z
end: ${lastdate}:00:00Z
step: PT6H
source_dir: $dataroot
source_file_fmt: '{source_dir}/satbias/{dump}.{year}{month}{day}/{hour}/atmos/{obs_type}_tlapmean.txt'
type: bc
database: shared
provider: gsi
file_type: tlapse
experiment: oper_$dump
obs_types:
  - aircraft
  - amsua_metop-a
  - amsua_metop-b
  - amsua_metop-c
  - amsua_n15
  - amsua_n18
  - amsua_n19
  - atms_n20
  - atms_npp
  - avhrr3_metop-a
  - avhrr3_n18
  - cris-fsr_n20
  - cris-fsr_npp
  - gome_metop-a
  - gome_metop-b
  - hirs4_metop-a
  - hirs4_n19
  - iasi_metop-a
  - iasi_metop-b
  - mhs_metop-a
  - mhs_metop-b
  - mhs_metop-c
  - mhs_n19
  - omi_aura
  - ompsnp_npp
  - ompstc8_npp
  - rass_tv
  #- saphir_meghat
  - satwind
  - sbuv2_n19
  - scatwind
  - seviri_m08
  - seviri_m11
  - sfc
  - sfcship
  - sondes
  - ssmis_f17
  - ssmis_f18
  - sst
  - vadwind
  #- windprof
EOF
  $r2d2storepy --config $dataroot/r2d2_store_tlapse.yaml
fi

if [ $r2d2store_bkg = "YES" ]; then
  cat > $dataroot/r2d2_store_bkg.yaml << EOF
start: ${firstdate}:00:00Z
end: ${lastdate}:00:00Z
step: PT6H
forecast_steps: [PT3H, PT4H, PT5H, PT6H, PT7H, PT8H, PT9H]
file_type_list: ['fv_core.res', 'fv_srf_wnd.res', 'fv_tracer.res', 'phy_data', 'sfc_data']
source_dir: $dataroot
source_file_fmt: '{source_dir}/{dump}.{year}{month}{day}/{hour}/atmos/RESTART/$(valid_date).$(file_type).tile$(tile).nc'
type: fc
model: gfs
resolution: c768
database: shared
dump: $dump
experiment: oper_$dump
tile: [1, 2, 3, 4, 5, 6]
user_date_format: '%Y%m%d.%H%M%S'
fc_date_rendering: 'analysis'
EOF
  $r2d2storepy --config $dataroot/r2d2_store_bkg.yaml
  cat > $dataroot/r2d2_store_coupler.yaml << EOF
start: ${firstdate}:00:00Z
end: ${lastdate}:00:00Z
step: PT6H
forecast_steps: [PT3H, PT4H, PT5H, PT6H, PT7H, PT8H, PT9H]
file_type_list: ['fv_core.res.nc', 'coupler.res']
source_dir: $dataroot
source_file_fmt: '{source_dir}/{dump}.{year}{month}{day}/{hour}/atmos/RESTART/$(valid_date).$(file_type)'
type: fc
model: gfs_metadata
resolution: c768
database: shared
dump: $dump
experiment: oper_$dump
user_date_format: '%Y%m%d.%H%M%S'
fc_date_rendering: 'analysis'
EOF
  $r2d2storepy --config $dataroot/r2d2_store_coupler.yaml
fi
