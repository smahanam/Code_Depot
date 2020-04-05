#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sat Mar 28 22:53:22 2020

@author: smahanam
"""

from bs4 import BeautifulSoup
import requests
from netCDF4 import Dataset
import numpy as np
import xarray as xr
import numpy.ma as ma
from datetime import datetime, timedelta
import os

M6_NAME = 'MCD15A2H'
MODIS_PATH = "https://ladsweb.modaps.eosdis.nasa.gov/opendap/hyrax/allData/6/" + M6_NAME + '/'
MAPL_UNDEF = np.float(1.e15)
NC = 86400
NR = 43200
IM = 43200
JM = 21600
DY = 180. / JM 
DX = 360. / IM
DXY = 360./NC
N_MODIS = 2400  
    
class DriverFunctions (object):
    def create_netcdf (FILE_NAME,VAR_NAMES):
        import datetime
        ncFidOut = Dataset(FILE_NAME,'w',format='NETCDF4')
        LatDim  = ncFidOut.createDimension('lat', JM)
        LonDim  = ncFidOut.createDimension('lon', IM)
        timeDim = ncFidOut.createDimension('time', None)
        
        ncFidOut.description = "MODIS " + M6_NAME + " @ " + str(DXY*3600) + ' arc-sec aggregated to ' + str(DX*3600) + ' arc-sec'
        ncFidOut.history     = "Created on " + datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S') + " by Sarith Mahanama (sarith.p.mahanama@nasa.gov)"
        
        # Variables
        lonout  = ncFidOut.createVariable('lon','f4',('lon',))
        latout  = ncFidOut.createVariable('lat','f4',('lat',))
        timeout = ncFidOut.createVariable('time', 'i', ('time',))
        doyout  = ncFidOut.createVariable('YYYYDoY', 'i', ('time',))

        for l in range (len(VAR_NAMES)):
            varout = ncFidOut.createVariable(VAR_NAMES[l], 'f4', ('time','lat','lon'), fill_value=MAPL_UNDEF)
            varout.units  = '1'
            setattr(ncFidOut.variables[VAR_NAMES[l]],'missing_value',np.float32(1.e15))
            setattr(ncFidOut.variables[VAR_NAMES[l]],'fmissing_value',np.float32(1.e15))

        datout  = ncFidOut.createVariable('REFERENCE_DATE','i', ('time',))
        
        # Attributes
        timeout.units = 'days since 2000-01-01 00:00:00'
        latout.units  = 'degrees north'
        lonout.units  = 'degrees east'
        doyout.units  = 'days from Jan 1'
        datout.units  = 'Date YYYYMMDD'
        
        varr    = np.full (IM, 0.)
        for i in range (IM):
            varr [i] = -180. + DX/2. + DX*i
        lonout [:] = varr
        
        varr    = np.full (JM,0.)
        for i in range (JM):
            varr [i] = DY*i + -90. + DY/2.  
        latout [:] = varr 
        
        ncFidOut.close()  
    
    def nearest_cell (array, value):
        array = np.asarray(array)
        idx = (np.abs(array - value)).argmin()
        return idx

    def fill_gaps (data, fill_value=None, ocean=None):
        NX = min (data.shape)
        data = ma.masked_array(data,data==fill_value)
        odata= ma.masked_array(data,data==ocean)

        for zoom in range (1,NX//2):
            for direction in (-1,1): 
                shift = direction * zoom
                if not np.any(data.mask): break
                for axis in (0,1):                
                    a_shifted = np.roll(data ,shift=shift,axis=axis)
                    o_shifted = np.roll(odata,shift=shift,axis=axis)
                    idx=~a_shifted.mask * data.mask*~o_shifted.mask
                    data[idx]=a_shifted[idx]
    
    def regrid_to_coarse (data):
        global NC, NR, IM, JM
        JX = NR // JM
        IX = NC // IM
        temp = data.reshape((data.shape[0] // JX, JX, data.shape[1] // IX, IX))
        return np.nanmean(temp, axis=(1,3))
    
    def get_tag_list(url,label):
        page = requests.get(url)
        soup = BeautifulSoup(page.content, 'html.parser')
        allfiles = soup.find_all(label)
        thislist = [tag.text for tag in allfiles]
        return thislist



class MCD15A2H (object):    

    #- read MCD15A2H granules    
    
    def __init__ (self, FILE_NAME):
        
        ds = xr.open_dataset(FILE_NAME, decode_coords = False)
#        lowright = [np.double(ds.XDim.max()),np.double(ds.YDim.min())]
#        upleft = [np.double(ds.XDim.min()),np.double(ds.YDim.max())]
        lat = np.double(ds.Latitude)
        lon = np.double(ds.Longitude)
        eastern_hemispehere = np.where(lon < -180.)
        western_hemispehere = np.where(lon >  180.)
        lon [eastern_hemispehere] = lon [eastern_hemispehere] + 360.
        lon [western_hemispehere] = lon [western_hemispehere] - 360.
        self.x_index = np.array(np.floor ((lon + 180.)/DXY),dtype=np.int)
        self.y_index = np.array(np.floor ((lat + 90.)/DXY) ,dtype=np.int)  

        
        # Read LAI
        # --------
        
        data = np.double(ds.Lai_500m)
        data [data < 0.] = MAPL_UNDEF
        invalid = data == MAPL_UNDEF
        data[invalid] = np.nan

        self.lai_500 =  data 
        
if not os.path.isfile('ExtData/' + M6_NAME + '.006_LAI_1km.nc4'):
    DriverFunctions.create_netcdf('ExtData/' + M6_NAME + '.006_LAI_1km.nc4',['MODIS_LAI'])

ncFidOut = Dataset('ExtData/' + M6_NAME + '.006_LAI_1km.nc4',mode='a')
IM = np.array (ncFidOut.variables['lon'][:]).size
JM = np.array (ncFidOut.variables['lat'][:]).size    
datestamp = ncFidOut.variables['REFERENCE_DATE']
LAIOUT    = ncFidOut.variables['MODIS_LAI']
timeout   = ncFidOut.variables['time']
doyout    = ncFidOut.variables['YYYYDoY']

# Processomh 8-day composites
if len(doyout) == 0: 
    d = 0
    years = DriverFunctions.get_tag_list(MODIS_PATH,"a")[1:-6]
    for year in years: 
        year = years[0]
        doys  = DriverFunctions.get_tag_list(MODIS_PATH + year,"a")[1:-6]
        if year == years[0]:
            date1 = datetime(int(year[0:4]),1,1) + timedelta (days=int(doys[0][0:3])-1) 
            date2 = date1 + timedelta (days=7)
            date0 = date1 + (date2 - date1)/2   
            timeout.units = 'days since ' + date0.strftime("%Y-%m-%d %H:%M:%S")
            
        for doy in doys:
            this_doy = int(doy[0:3])
            date1 = datetime(int(year[0:4]),1,1) + timedelta (days=this_doy-1)
            if this_doy < 361:
                date2 = date1 + timedelta (days=8)
            else:
                date2 = datetime(int(years[1][0:4])+1,1,1)
            mday  = date1 + (date2 - date1)/2
            datestamp[d] = int(mday.strftime("%Y%m%d")) 
            timeout[d]   = (mday - date0).days
            doyout [d]   = 1000*int(year[0:4]) +  int(doy[0:3])
            
            files = DriverFunctions.get_tag_list(MODIS_PATH + year + doy,"span")[1:-1]
            lai_high = np.full((NR,NC),np.nan)
            
            for f in range(len(files)):
                FILE_NAME = MODIS_PATH + year + doy + files[f]
                print(FILE_NAME)
                thistile = MCD15A2H (FILE_NAME)
                lai_mask = np.where((thistile.lai_500 >= 0.) & (thistile.lai_500 <= 10.))
                lai_array= thistile.lai_500.reshape (N_MODIS*N_MODIS)
                xin_array= thistile.x_index.reshape (N_MODIS*N_MODIS)
                yin_array= thistile.y_index.reshape (N_MODIS*N_MODIS)
                lai_mask = np.where((lai_array >= 0.) & (lai_array <= 10.))
                lai_high [yin_array[lai_mask],xin_array[lai_mask]] = lai_array[lai_mask]
                
            lai_low   = DriverFunctions.regrid_to_coarse(lai_high)
            invalid   = np.ma.masked_invalid(lai_low)    
    #    lai_low [invalid.mask] = -9999.
            lai_low [invalid.mask] = 0.
    #            lai_low [noland] = MAPL_UNDEF
    #    DriverFunctions.fill_gaps (lai_low, fill_value=-9999., ocean=MAPL_UNDEF)
            LAIOUT[d] = lai_low
            d = d + 1
            
else:
    print ('Update data set')
                               
ncFidOut.close()

