# spdtst.R
# ========
#
#     Read the data written by speedtest-cli, prepare and plot these
#
# Copyright (C) MMHein.at/January 2017
#======================================================================

########################################################################
## library & module section
library(compiler)
library(lubridate)
library(data.table)
library(ggplot2)
library(gridExtra)
library(grid)
library(RColorBrewer)

########################################################################
## global constant & variable section
ops <- options()

ISP_NAME <- "WIOCC"
ISP_PROD <- "Metro Connect"
ISP_SPD_DL <- 100           # ISP download speed [mbit / s]
ISP_SPD_UL <- 7.5           # ISP upload speed [mbit / s]
ISP_SPD_LVL <- list(lbl=c("non-acceptable", "bad", "poor", "mediocre", "good", "excellent"),
                    lvl=c(-100, 0.5, 0.6, 0.75, 0.85, 0.97, 100),
                    col=c("darkred", "red", "orange", "yellow", "yellowgreen", "green"))
ISP_LAT_LVL <- list(lbl=c("excellent", "good", "mediocre", "poor", "bad", "non-acceptable"),
                    lvl=c(0.0, 10.0, 25.0, 50.0, 100.0, 200.0, 1000000.0),
                    col=c("green", "yellowgreen", "yellow", "orange", "red", "darkred"))

TM_LVL <- list(lbl=c("night", "morning", "mid-morning", "midday", "afternoon", "evening", "night"),
               lvl=c("00:00:00", "04:30:00", "09:30:00", "11:30:00", "14:00:00", "17:30:00", 
                     "21:30:00", "23:59:59"),
               col=c())

fnlog <- file.path("data/spdtst.log")
cnraw <- c("Server ID", "Sponsor", "Server Name", "Timestamp", "Distance", 
           "Ping", "Download", "Upload")
clraw <- c("factor", "factor", "factor", "POSIXct", "double", "double",
           "double", "double")
cnfin <- c("Date", "Time", "Timestamp", "Week", "DoW", "ToD", 
           "Ping", "PCat", "Download", "DLCat", "Upload", "ULCat",
           "Server ID", "Sponsor", "Server Name", "Distance")
dt <- data.table(NULL)

########################################################################
## main section
options(digits.secs=9)

# read & prepare data
dt <- fread(fnlog, sep=";", stringsAsFactors=FALSE, colClasses=clraw)
dt[, `:=`(Timestamp=ymd_hms(Timestamp),
          Week=as.factor(week(Timestamp)), 
          DoW=as.factor(lubridate::wday(Timestamp, label=TRUE)), 
          Date=date(Timestamp),
          Time=lapply(strsplit(Timestamp, "T"), function(x) { x[2] }), 
          ToD=Timestamp,
          PCat=cut(Ping, ISP_LAT_LVL$lvl, 
                   right=FALSE, include.lowest=TRUE, labels=ISP_LAT_LVL$lbl),
          DLCat=cut(Download, ISP_SPD_LVL$lvl * ISP_SPD_DL * 1024^2, 
                    right=FALSE, include.lowest=TRUE, labels=ISP_SPD_LVL$lbl),
          ULCat=cut(Upload, ISP_SPD_LVL$lvl * ISP_SPD_UL * 1024^2, 
                    right=FALSE, include.lowest=TRUE, labels=ISP_SPD_LVL$lbl))]
setcolorder(dt, cnfin)

### TODO: tidy data!

# plot data
# prepare category-specific colours
gcols <- ISP_SPD_LVL$col
names(gcols) <- ISP_SPD_LVL$lbl
gcoll <- ISP_LAT_LVL$col
names(gcoll) <- ISP_LAT_LVL$lbl

# timeline data
gdn <- ggplot(data=dt, aes(Timestamp, Download / 1024^2)) +
       geom_line(aes(colour=DLCat, group=1), show.legend=FALSE) +
       scale_colour_manual(values=gcols) +
       geom_hline(yintercept=ISP_SPD_DL, colour="seagreen", lty="dashed") +
       geom_smooth(method="lm", formula=y~x) +
       ylim(0, 100) +
       labs(x="Time", y="Download Speed [mbit / s]")
gup <- ggplot(data=dt, aes(Timestamp, Upload / 1024^2)) +
       geom_line(aes(colour=ULCat, group=1), show.legend=FALSE) +
       scale_colour_manual(values=gcols) +
       geom_hline(yintercept=ISP_SPD_UL, colour="seagreen", lty="dashed") +
       geom_smooth(method="lm", formula=y~x) +
       ylim(0, 6.5) +
       labs(x="Time", y="Upload Speed [mbit / s]")
gpg <- ggplot(data=dt, aes(Timestamp, Ping)) +
       geom_line(aes(colour=PCat, group=1), show.legend=FALSE) +
       scale_colour_manual(values=gcoll) +
       geom_smooth(method="lm", formula=y~x) +
       labs(x="Time", y="Latency [ms]")

# chart title, sub-title & legend
gmt <- textGrob("Internet Speed Monitoring", gp=gpar(fontsize=20))
gst <- textGrob(paste("(", ISP_NAME, " / ", ISP_PROD, ")", sep=""), gp=gpar(fontsize=12))
margin <- unit(0.5, "line")
glgd <- legendGrob(ISP_SPD_LVL$lbl, nrow=1, do.lines=TRUE,
                   gp=gpar(col=ISP_SPD_LVL$col, fontsize=10))

# arrange chart elements & display plot
grid.arrange(gmt, gst, gdn, gup, gpg, glgd, nrow=6, ncol=1,
             heights=unit.c(grobHeight(gmt) + 1.2 * margin, 
                            grobHeight(gst) + margin, 
                            unit(1, "null"), unit(1, "null"), unit(1, "null"),
                            glgdh))

# clean up
options(ops)

#======================================================================
# end of file
#