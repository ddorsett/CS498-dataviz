#
# pivot and summarization of GHCD data processing
# - expects GHCD format input CSV files, named by station and year in 'tmp' subdirectory
# - writes output CSV into 'out' subdirectory

# D. Dorsettt 20-Jul-2019

library(tidyverse)
library(lubridate)
library(here)
setwd("E:/WeatherData/out")

stations <- c("USW00014764","USW00014739","USW00014758","USW00094789","USW00013739","USW00093721","USW00013750","USW00013748","USW00013782","USC00084366","USW00012849","USW00092811")

numericcols <- c("TMAX_MIN","TMAX_MAX","TMAX_MEAN",
"TMIN_MIN","TMIN_MAX","TMIN_MEAN",
"PRCP_MAX","PRCP_MEAN","PRCP_TOTAL",
"SNOW_MAX","SNOW_MEAN","SNOW_TOTAL",
"SNWD_MAX","SNWD_MEAN",
"PRCP_DAYS","SNOW_DAYS","WINDEVENTS")

# these frames contain data across all stations and all years
monthly_baseline <- data.frame()
weekly_baseline <- data.frame()
season_baseline <- data.frame()
season_all <- data.frame()

# process 1 station at a time
for (i in 1:length(stations)) {

	# read all years of input data per station
	file_list <- list.files(path="E:/WeatherData/tmp", paste0(stations[i],".*.csv"))

	# these summaries are per station for all years
	monthly_summary <- data.frame()
	weekly_summary <- data.frame()
	season_summary <- data.frame()
	for (y in 1:length(file_list)) {
		# some years have no data
		if (!file.size(paste0("E:/WeatherData/tmp/",file_list[y])) == 0) {
			print(paste("Processing", file_list[y]))
			raw <- read.csv(paste0("E:/WeatherData/tmp/",file_list[y]), header=FALSE) %>% select(1,2,3,4)
			names(raw) <- c("station","date","tag","value")

			# extract year,month,week,season and pivot based on GHCD dataset tag
			station_data <- raw %>%
				mutate(DATE=ymd(date)) %>% mutate(YEAR=year(date),MONTH=month(date), WEEK=trunc((yday(date)-1)/7)+1, SEASON=case_when(MONTH>2 & MONTH<6 ~ "spring",MONTH>5 & MONTH<9 ~ "summer",MONTH>8 & MONTH<12 ~ "fall",TRUE ~ "winter")) %>%
				pivot_wider(names_from=tag, values_from=value)

			# convert temp from tenths degC to degF also add dummy columns for aggregation if needed (not all tags in all dataaets)
			if ("TMAX" %in% colnames(station_data)) { station_data$TMAX <- ((station_data$TMAX / 10.0) * (9.0 / 5.0)) + 32.0 } else { station_data <- mutate(station_data, TMAX=NA) }
			if ("TMIN" %in% colnames(station_data)) { station_data$TMIN <- ((station_data$TMIN / 10.0) * (9.0 / 5.0)) + 32.0 } else { station_data <- mutate(station_data, TMIN=NA) }
			# converet lengths from mm to inch also add dummy columns for aggregation if needed
			if ("PRCP" %in% colnames(station_data)) { station_data$PRCP <- station_data$PRCP / 254.0 } else { station_data <- mutate(station_data, PRCP=NA) }
			if ("SNOW" %in% colnames(station_data)) { station_data$SNOW <- station_data$SNOW / 254.0 } else { station_data <- mutate(station_data, SNOW=NA) }
			if ("SNWD" %in% colnames(station_data)) { station_data$SNWD <- station_data$SNWD / 254.0 } else { station_data <- mutate(station_data, SNWD=NA) }
			if ("EVAP" %in% colnames(station_data)) { station_data$EVAP <- station_data$EVAP / 254.0 } else { station_data <- mutate(station_data, EVAP=NA) }
			if ("WESD" %in% colnames(station_data)) { station_data$WESD <- station_data$WESD / 254.0 } else { station_data <- mutate(station_data, WESD=NA) }
			if ("WESF" %in% colnames(station_data)) { station_data$WESF <- station_data$WESF / 254.0 } else { station_data <- mutate(station_data, WESF=NA) }
			# convert speed from cm/s to mph also add dummy columns for aggregation if needed
			if ("AWND" %in% colnames(station_data)) { station_data$AWND <- station_data$AWND * 360000.0 / 1609344.0 } else { station_data <- mutate(station_data, AWND=NA) }
			if ("WSF1" %in% colnames(station_data)) { station_data$WSF1 <- station_data$WSF1 * 360000.0 / 1609344.0 } else { station_data <- mutate(station_data, WSF1=NA) }
			if ("WSF2" %in% colnames(station_data)) { station_data$WSF2 <- station_data$WSF2 * 360000.0 / 1609344.0 } else { station_data <- mutate(station_data, WSF2=NA) }
			if ("WSF5" %in% colnames(station_data)) { station_data$WSF5 <- station_data$WSF5 * 360000.0 / 1609344.0 } else { station_data <- mutate(station_data, WSF5=NA) }
			if ("WSFG" %in% colnames(station_data)) { station_data$WSFG <- station_data$WSFG * 360000.0 / 1609344.0 } else { station_data <- mutate(station_data, WSFG=NA) }
			if ("WSFI" %in% colnames(station_data)) { station_data$WSFI <- station_data$WSFI * 360000.0 / 1609344.0 } else { station_data <- mutate(station_data, WSFI=NA) }
			if ("WSFM" %in% colnames(station_data)) { station_data$WSFM <- station_data$WSFM * 360000.0 / 1609344.0 } else { station_data <- mutate(station_data, WSFM=NA) }
			if (!"TSUN" %in% colnames(station_data)) { station_data <- mutate(station_data, TSUN=NA) }
			if (!"WT11" %in% colnames(station_data)) { station_data <- mutate(station_data, WT11=NA) }
			if (!"WT10" %in% colnames(station_data)) { station_data <- mutate(station_data, WT10=NA) }

			# group by season and summarize
			group <- station_data %>% group_by(YEAR, SEASON)
			# summaize to create number of days with recorded rainfall and snow
			group <- left_join(group, group %>% filter(PRCP > 0) %>% summarise(PRCP_DAYS=n()), by=c("YEAR","SEASON"))
			group <- left_join(group, group %>% filter(SNOW > 0) %>% summarise(SNOW_DAYS=n()), by=c("YEAR","SEASON"))
			group <- left_join(group, group %>% filter(WT10 > 0 | WT11 > 0) %>% summarise(WINDEVENTS=n()), by=c("YEAR","SEASON"))
			summary <- group %>% summarise(
				TMIN_MIN=min(TMIN, na.rm = TRUE), TMIN_MAX=max(TMIN, na.rm = TRUE), TMIN_MEAN=mean(TMIN, na.rm = TRUE),
				TMAX_MIN=min(TMAX, na.rm = TRUE), TMAX_MAX=max(TMAX, na.rm = TRUE), TMAX_MEAN=mean(TMAX, na.rm = TRUE),
				PRCP_MAX=max(PRCP, na.rm = TRUE), PRCP_MEAN=mean(PRCP, na.rm = TRUE), PRCP_TOTAL=sum(PRCP, na.rm = TRUE),
				SNOW_MAX=max(SNOW, na.rm = TRUE), SNOW_MEAN=mean(SNOW, na.rm = TRUE), SNOW_TOTAL=sum(SNOW, na.rm = TRUE),
				SNWD_MAX=max(SNWD, na.rm = TRUE), SNWD_MEAN=mean(SNWD, na.rm = TRUE),
				PRCP_DAYS=min(PRCP_DAYS, na.rm = FALSE), SNOW_DAYS=min(SNOW_DAYS, na.rm = FALSE), WINDEVENTS=min(WINDEVENTS, na.rm = FALSE)
			) %>% mutate(STATION=stations[i])
			season_summary <- bind_rows(season_summary, summary)

			# summarize by month
			group <- station_data %>% group_by(YEAR, MONTH)
			group <- left_join(group, group %>% filter(PRCP > 0) %>% summarise(PRCP_DAYS=n()), by=c("YEAR","MONTH"))
			group <- left_join(group, group %>% filter(SNOW > 0) %>% summarise(SNOW_DAYS=n()), by=c("YEAR","MONTH"))
			group <- left_join(group, group %>% filter(WT10 > 0 | WT11 > 0) %>% summarise(WINDEVENTS=n()), by=c("YEAR","MONTH"))
			summary <- group %>% summarise(
				TMIN_MIN=min(TMIN, na.rm = TRUE), TMIN_MAX=max(TMIN, na.rm = TRUE), TMIN_MEAN=mean(TMIN, na.rm = TRUE),
				TMAX_MIN=min(TMAX, na.rm = TRUE), TMAX_MAX=max(TMAX, na.rm = TRUE), TMAX_MEAN=mean(TMAX, na.rm = TRUE),
				PRCP_MAX=max(PRCP, na.rm = TRUE), PRCP_MEAN=mean(PRCP, na.rm = TRUE), PRCP_TOTAL=sum(PRCP, na.rm = TRUE),
				SNOW_MAX=max(SNOW, na.rm = TRUE), SNOW_MEAN=mean(SNOW, na.rm = TRUE), SNOW_TOTAL=sum(SNOW, na.rm = TRUE),
				SNWD_MAX=max(SNWD, na.rm = TRUE), SNWD_MEAN=mean(SNWD, na.rm = TRUE),
				PRCP_DAYS=min(PRCP_DAYS, na.rm = FALSE), SNOW_DAYS=min(SNOW_DAYS, na.rm = FALSE), WINDEVENTS=min(WINDEVENTS, na.rm = FALSE)
			) %>% mutate(STATION=stations[i], DATE=sprintf("%02d-%04d", MONTH, YEAR))
			monthly_summary <- bind_rows(monthly_summary, summary)

			# summarize by week
			group <- station_data %>% group_by(YEAR, WEEK)
			group <- left_join(group, group %>% filter(PRCP > 0) %>% summarise(PRCP_DAYS=n()), by=c("YEAR","WEEK"))
			group <- left_join(group, group %>% filter(SNOW > 0) %>% summarise(SNOW_DAYS=n()), by=c("YEAR","WEEK"))
			group <- left_join(group, group %>% filter(WT10 > 0 | WT11 > 0) %>% summarise(WINDEVENTS=n()), by=c("YEAR","WEEK"))
			summary <- group %>% summarise(
				TMIN_MIN=min(TMIN, na.rm = TRUE), TMIN_MAX=max(TMIN, na.rm = TRUE), TMIN_MEAN=mean(TMIN, na.rm = TRUE),
				TMAX_MIN=min(TMAX, na.rm = TRUE), TMAX_MAX=max(TMAX, na.rm = TRUE), TMAX_MEAN=mean(TMAX, na.rm = TRUE),
				PRCP_MAX=max(PRCP, na.rm = TRUE), PRCP_MEAN=mean(PRCP, na.rm = TRUE), PRCP_TOTAL=sum(PRCP, na.rm = TRUE),
				SNOW_MAX=max(SNOW, na.rm = TRUE), SNOW_MEAN=mean(SNOW, na.rm = TRUE), SNOW_TOTAL=sum(SNOW, na.rm = TRUE),
				SNWD_MAX=max(SNWD, na.rm = TRUE), SNWD_MEAN=mean(SNWD, na.rm = TRUE),
				PRCP_DAYS=min(PRCP_DAYS, na.rm = FALSE), SNOW_DAYS=min(SNOW_DAYS, na.rm = FALSE), WINDEVENTS=min(WINDEVENTS, na.rm = FALSE)
			) %>% mutate(STATION=stations[i], DATE=sprintf("%02d-%04d", WEEK, YEAR))
			weekly_summary <- bind_rows(weekly_summary, summary)
		}
	}

	# finished all years for a station, separate data before 1969 for baselines (which will be accumulate across all stations)
	baseline <- season_summary %>% filter(YEAR < 1969) %>% group_by(SEASON) %>% summarise(
		TMIN_MIN=min(TMIN_MIN, na.rm = TRUE), TMIN_MAX=max(TMIN_MAX, na.rm = TRUE), TMIN_MEAN=mean(TMIN_MEAN, na.rm = TRUE),
		TMAX_MIN=min(TMAX_MIN, na.rm = TRUE), TMAX_MAX=max(TMAX_MAX, na.rm = TRUE), TMAX_MEAN=mean(TMAX_MEAN, na.rm = TRUE),
		PRCP_MAX=max(PRCP_MAX, na.rm = TRUE), PRCP_MEAN=mean(PRCP_TOTAL, na.rm = TRUE),
		SNOW_MAX=max(SNOW_MAX, na.rm = TRUE), SNOW_MEAN=mean(SNOW_TOTAL, na.rm = TRUE),
		SNWD_MAX=max(SNWD_MAX, na.rm = TRUE), SNWD_MEAN=mean(SNWD_MEAN, na.rm = TRUE),
		PRCP_DAYS=mean(PRCP_DAYS, na.rm = TRUE), SNOW_DAYS=mean(SNOW_DAYS, na.rm = TRUE), WINDEVENTS=mean(WINDEVENTS, na.rm = TRUE)
	) %>% mutate(STATION=stations[i])
	season_baseline <- bind_rows(season_baseline, baseline)
	season_summary <- season_summary %>% filter(YEAR > 1968)
	season_all <- bind_rows(season_all, season_summary)

	# summarize into monthly baseline and write CSV for this station
	baseline <- monthly_summary %>% filter(YEAR < 1969) %>% group_by(MONTH) %>% summarise(
		TMIN_MIN=min(TMIN_MIN, na.rm = TRUE), TMIN_MAX=max(TMIN_MAX, na.rm = TRUE), TMIN_MEAN=mean(TMIN_MEAN, na.rm = TRUE),
		TMAX_MIN=min(TMAX_MIN, na.rm = TRUE), TMAX_MAX=max(TMAX_MAX, na.rm = TRUE), TMAX_MEAN=mean(TMAX_MEAN, na.rm = TRUE),
		PRCP_MAX=max(PRCP_MAX, na.rm = TRUE), PRCP_MEAN=mean(PRCP_TOTAL, na.rm = TRUE),
		SNOW_MAX=max(SNOW_MAX, na.rm = TRUE), SNOW_MEAN=mean(SNOW_TOTAL, na.rm = TRUE),
		SNWD_MAX=max(SNWD_MAX, na.rm = TRUE), SNWD_MEAN=mean(SNWD_MEAN, na.rm = TRUE),
		PRCP_DAYS=mean(PRCP_DAYS, na.rm = TRUE), SNOW_DAYS=mean(SNOW_DAYS, na.rm = TRUE), WINDEVENTS=mean(WINDEVENTS, na.rm = TRUE)
	) %>% mutate(STATION=stations[i])
	monthly_baseline <- bind_rows(monthly_baseline, baseline)
	# convert missing data into -999 (out of range of everything), write montly data from 1969
	monthly_summary <- monthly_summary %>% filter(YEAR > 1968)
	monthly_summary <- monthly_summary %>% mutate_at(numericcols, ~replace(.,is.na(.),-999)) %>% mutate_at(numericcols, ~replace(.,is.infinite(.),-999))
	monthly_summary <- monthly_summary[order(monthly_summary$YEAR, monthly_summary$MONTH),]
	write.csv(monthly_summary, paste0(stations[i],".monthly.csv"), row.names=FALSE)

	# summarize into weekly baseline and write CSV for this station
	baseline <- weekly_summary %>% filter(YEAR < 1969) %>% group_by(WEEK) %>% summarise(
		TMIN_MIN=min(TMIN_MIN, na.rm = TRUE), TMIN_MAX=max(TMIN_MAX, na.rm = TRUE), TMIN_MEAN=mean(TMIN_MEAN, na.rm = TRUE),
		TMAX_MIN=min(TMAX_MIN, na.rm = TRUE), TMAX_MAX=max(TMAX_MAX, na.rm = TRUE), TMAX_MEAN=mean(TMAX_MEAN, na.rm = TRUE),
		PRCP_MAX=max(PRCP_MAX, na.rm = TRUE), PRCP_MEAN=mean(PRCP_TOTAL, na.rm = TRUE),
		SNOW_MAX=max(SNOW_MAX, na.rm = TRUE), SNOW_MEAN=mean(SNOW_TOTAL, na.rm = TRUE),
		SNWD_MAX=max(SNWD_MAX, na.rm = TRUE), SNWD_MEAN=mean(SNWD_MEAN, na.rm = TRUE),
		PRCP_DAYS=mean(PRCP_DAYS, na.rm = TRUE), SNOW_DAYS=mean(SNOW_DAYS, na.rm = TRUE), WINDEVENTS=mean(WINDEVENTS, na.rm = TRUE)
	) %>% mutate(STATION=stations[i])
	weekly_baseline <- bind_rows(weekly_baseline, baseline)
	weekly_summary <- weekly_summary %>% filter(YEAR > 1968)
	weekly_summary <- weekly_summary %>% mutate_at(numericcols, ~replace(.,is.na(.),-999)) %>% mutate_at(numericcols, ~replace(.,is.infinite(.),-999))
	weekly_summary <- weekly_summary[order(weekly_summary$YEAR, weekly_summary$WEEK),]
	write.csv(weekly_summary, paste0(stations[i],".weekly.csv"), row.names=FALSE)
}

## finished all stations and all years!
# write final CSV summary datafile
season_baseline <- season_baseline %>% mutate_at(c("PRCP_DAYS","SNOW_DAYS","WINDEVENTS"), ~replace(.,is.na(.),0))
write.csv(season_baseline, "season_baseline.csv", row.names=FALSE)
monthly_baseline <- monthly_baseline %>% mutate_at(c("PRCP_DAYS","SNOW_DAYS","WINDEVENTS"), ~replace(.,is.na(.),0))
write.csv(monthly_baseline, "monthly_baseline.csv", row.names=FALSE)
weekly_baseline <- weekly_baseline %>% mutate_at(c("PRCP_DAYS","SNOW_DAYS","WINDEVENTS"), ~replace(.,is.na(.),0))
write.csv(weekly_baseline, "weekly_baseline.csv", row.names=FALSE)
season_all <- season_all %>% mutate_at(c("PRCP_DAYS","SNOW_DAYS","WINDEVENTS"), ~replace(.,is.na(.),0))
write.csv(season_all, "seasons.csv", row.names=FALSE)