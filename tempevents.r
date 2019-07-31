#
# generate multi-day events from summarized GHCD data
# - expects GHCD format input CSV files, named by station and year in 'tmp' subdirectory
#     (created by fileterData.py)
# - expects seaonsalseaonabl baseline data for all stations in a single CSV file 'season_baseline.csv' in the 'out' subdirectory
#     (this is created by summarize.r)
# - writes output temperature events CSV into 'out' subdirectory

# D. Dorsettt 20-Jul-2019

library(tidyverse)
library(lubridate)
library(here)
setwd("E:/WeatherData/out")

stations <- c("USW00014764","USW00014739","USW00014758","USW00094789","USW00013739","USW00093721","USW00013750","USW00013748","USW00013782","USC00084366","USW00012849","USW00092811")

# pull baseline data
season_baseline <- read.csv("season_baseline.csv")
seasons <- c("spring","summer","fall","winter")

# this is the data frame we're building
tempevents <- data.frame(matrix(ncol=6,nrow=0))
names(tempevents) = c("STATION","YEAR","SEASON","TYPE","EVENT","LABEL")

# go back through daily temperatiure data looking for cold/heat waves based on station highest average max and lowest average min through the whole year
for (i in 1:length(stations)) {
	station = stations[i]
	file_list <- list.files(path="E:/WeatherData/tmp", paste0(station,".*.csv"))
	statavg <- season_baseline %>% filter(STATION==station)
	maxtemp = max(statavg$TMAX_MEAN)
	mintemp = min(statavg$TMIN_MEAN)

	for (y in 1:length(file_list)) {
		if (!file.size(paste0("E:/WeatherData/tmp/",file_list[y])) == 0) {
			print(paste("Processing", file_list[y]))
			raw <- read.csv(paste0("E:/WeatherData/tmp/",file_list[y]), header=FALSE) %>% select(1,2,3,4)
			names(raw) <- c("station","date","tag","value")
			raw <- raw %>% filter(tag == "TMAX")

			# extract year,month,week,season and pivot based on GHCD dataset tag
			hight_data <- raw %>%
				mutate(DATE=ymd(date),YEAR=year(date),MONTH=month(date),SEASON=case_when(MONTH>2 & MONTH<6 ~ "spring",MONTH>5 & MONTH<9 ~ "summer",MONTH>8 & MONTH<12 ~ "fall",TRUE ~ "winter")) %>%
				pivot_wider(names_from=tag, values_from=value)
			# convert temp from tenths degC to degF
			if ("TMAX" %in% colnames(hight_data)) { hight_data$TMAX <- ((hight_data$TMAX / 10.0) * (9.0 / 5.0)) + 32.0 } else { hight_data <- mutate(hight_data, TMAX=NA) }

			# mark the HOT days as more than 9 deg about the average maximum and COLD days as more than 9 deg colder than the average minimum
			hight_data <- hight_data %>% mutate(HOT=TMAX > (maxtemp + 9), COLD=TMAX < (mintemp - 9))

			# summzrize by season
			for (ss in 1:length(seasons)) {
				season = seasons[ss]
				season_avgt <- hight_data %>% filter(SEASON==season)
				# run-length-encode to reduce to vectors of streaks
				streaks <- rle(season_avgt$HOT)
				drow = 1
				if (length(streaks$lengths > 0)) {
					for (r in 1:length(streaks$values)) {
						# write the starting day of streaks where  HOT as TRUE and more than 3 days in length
						if (streaks$values[r] && streaks$lengths[r] > 3) {
							tempevents <- add_row(tempevents, STATION=station, YEAR=season_avgt$YEAR[drow], SEASON=season, TYPE="TMAX", EVENT="Heat Wave",LABEL=sprintf("%d days", streaks$length[r]))
						}
						drow = drow + streaks$lengths[r]
					}
				}
				streaks <- rle(season_avgt$COLD)
				drow = 1
				if (length(streaks$lengths > 0)) {
					for (r in 1:length(streaks$values)) {
						# write the starting day of streaks where COLD as TRUE and more than 3 days in length
						if (streaks$values[r] & streaks$lengths[r] > 3) {
							tempevents <- add_row(tempevents, STATION=station, YEAR=season_avgt$YEAR[drow], SEASON=season, TYPE="TMIN", EVENT="Cold Wave",LABEL=sprintf("%d days", streaks$length[r]))
						}
						drow = drow + streaks$lengths[r]
					}
				}
			}
		}
	}
}
# write CSV summary datafile
write.csv(tempevents, "tempevents.csv", row.names=FALSE)
