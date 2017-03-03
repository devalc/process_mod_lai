#!/bin/bash

####################################
#The script reads all the modis reprojected lai files in tif format and uses a raster calculator operations to set the 
#filled and missing values.
#following the abouve operation the script renames the modis datevalues from the filename to the actual dates.
#These files are then translated into a netcdf file using the GDAL functionality and the reference time and 
#the date attributes are set for each file. 
#the files are then merged into one netcdf using the CDO functionality.
#Next the variable in the file is renamed to a more appropriate one.  
######################################


#modify the fill values and the pixel values that are set for areas for which LAI could not be calculated
for i in *.tif
do
gdal_calc.py -A $i --calc="-999*(A>=255)+0*(A==249)+0*(A==250)+0*(A==251)+0*(A==252)+0*(A==253)+0*(A==254)+A*(A<=100)" --NoDataValue=-999 --outfile=set0$i
gdal_calc.py -A set0$i --calc="A*0.1" --NoDataValue=-999 --outfile=S$i
rm set0$i
done

#rename dates in the default modis file nomenclature

yyyymmdd () { date -d "$1-01-01 +$2 days -1 day" "+%Y.%m.%d"; }

for f in SMOD*.tif; do
    YYYY=${f:10:4}
    DDD=${f:14:3}
    date= $(yyyymmdd $YYYY $DDD) 
    echo $date 
    OUT="${f/.*/}".$(yyyymmdd $YYYY $DDD).mosaic.Lai_1km.tif

    mv "$f" "$OUT"
done

#write tiff file to a netcdf file and set time axis

echo "List of all files with prefix SMOD"
ls -al SMOD*.tif

echo "looping thru all files with prefix SMOD"
for i in `find . -name "SMOD*.tif" -type f`; do
    echo "getting date value"
    year=$(echo $i | cut -d"." -f3 | cut -d"." -f1); echo $year
    month=$(echo $i | cut -d"." -f4 | cut -d"." -f1); echo $month
    day=$(echo $i | cut -d"." -f5 | cut -d"." -f1); echo $day
    datevalue=$(date -d "$year-$month-$day" +"%Y-%m-%d");echo $datevalue
    echo $i
          
    gdal_translate -ot Int16 -of netCDF SMOD15A2.$year.$month.$day.mosaic.Lai_1km.tif SMOD15A2.$year.$month.$day.mosaic.Lai_1km.nc
    cdo setreftime,2001-01-01,00:00:00 SMOD15A2.$year.$month.$day.mosaic.Lai_1km.nc srt_SMOD15A2.$year.$month.$day.mosaic.Lai_1km.nc
    rm SMOD*.nc
    cdo setdate,$datevalue srt_SMOD15A2.$year.$month.$day.mosaic.Lai_1km.nc sd_SMOD15A2.$year.$month.$day.mosaic.Lai_1km.nc
    rm srt_*.nc
done
cdo mergetime sd_*.nc MOD15A2_2001_to_2007_igbextent_Lai_1km.nc
ncrename -v Band1,Lai MOD15A2_2001_to_2007_igbextent_Lai_1km.nc
