#
# filterData.py filters GHCN daily data by station
#  - expects source GZIP CSV files in GHCN format in 'raw' subdirectory
#  - writes filtered CSV in 'tmp' subdirectory

# D. Dorsett 20-Jul-2019

import sys
import glob
import gzip
import datetime

# open a GZIP CSV data file, where the first 11 characters is the station id and the remainder of the line is the observation data
def filter_station(in_filename, out_filename, stationKey):
	with gzip.open(in_filename, 'rt') as in_f, open(out_filename, 'w') as out_f:
		for line in in_f:
			if line[:11] in stationKey:
				yr = line[11:16]
				mo = line[16:18]
				dt = line[18:20]
				out_f.write(line[:11]+yr+'-'+mo+'-'+dt+line[20:])

# GHCN station Id from the command line
if len(sys.argv) < 2:
	print('Usage: fileData.py {stationCode}')
	sys.exit(1)
station = sys.argv[1]

# process all raw GHCN CSV data and create CSV subsets with a single station
for file in glob.glob('./raw/*.gz'):
	i = file.find('.', 6)
	year = file[6:i]
	print(datetime.datetime.now().strftime("%H:%M:%S") + ': filtering ' + station + ' ' + year)
	filter_station(file, './tmp/'+station+'.'+year+'.csv', station)

print(datetime.datetime.now().strftime("%H:%M:%S") + ': filtering complete')
