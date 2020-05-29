## ----setup, include=FALSE----------------------------------------------------------------------------
# if not installed yet, install required packages
list.of.packages <- c("ggplot2", "deSolve", "progress", "parallel", "doSNOW", "cowplot", "abind", "tidyr", "tgp", "hrbrthemes", "powdist", "GGally", "PerformanceAnalytics")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

if (exists("cl")) {
  rm(list=ls()[-(which(ls() == "cl"))])
} else {
  rm(list=ls())
}

# library(viridis)
# library(psych)

# library for simulations
library(deSolve)

# libraries for parallel computing
library(parallel)
library(doSNOW)

# library for progress bar
library(progress)

# library for binding multidimensional arrays/data transformation
library(abind)
library(tidyr)

# libraries for plotting
library(ggplot2)
library(cowplot)
library(hrbrthemes)
library(GGally)
library(PerformanceAnalytics)

# library for LHS sampling
library(tgp)

# source external file to define helper functions ----
# for schedule, temperature and rain curve, parameters
source("./schedules.climate.parameters.R")
source("./modelsRun.R")
source("./stochastics.R")

## -define latin hypercube sample ---------------------------------------------------------------------------------------------------
days <- 365
timestep <- 5*60
n_lhs <- 128
version <- paste0("allModelsVersion3.2.LHS", ".", days, "days.n_lhs=", n_lhs)

param_names <- c("A_roof", "h_tank","n_taps","z", "h_0", "r_tank", "h_air", "c_0", "T_water_0") 
param_range_matrix <- matrix(c(100, 2, 1, 0, 0, 1, 0, 1.55*10^-5, 10,
                               1000, 10, 20, 5, 5, 5, 5, 1.55*10^-4, 30)
                             , length(param_names)) 
rownames(param_range_matrix) <- param_names

param_sets_lhs <- lhs(n=n_lhs, rect=param_range_matrix) 
colnames(param_sets_lhs) <- param_names

# round n_taps beacause that should be integers
param_sets_lhs[, "n_taps"] <- round(param_sets_lhs[, "n_taps"])
param_sets_lhs <- as.data.frame(param_sets_lhs)

## -run models---------------------------------------------------------------------------------------------------
numCores <- detectCores()
if(!exists("cl")) cl <- makeCluster(numCores)
registerDoSNOW(cl)

progress <- function(i) pb$tick()
pb <- progress_bar$new(
  format = "[:bar] :current/:total runs | elapsed::elapsed",
  total = n_lhs, clear = FALSE)
opts <- list(progress=progress)
bind3d <- function(...) abind(..., along = 3)

startTime <- Sys.time()
outLHS <-foreach(i=1:n_lhs, .options.snow=opts, .packages = c("deSolve", "powdist"), .combine = bind3d) %dopar% {
  # define startParameters according to LHS
  lhs_set <- param_sets_lhs[i,]
  startParameters <- defineParameters(A_roof = lhs_set$A_roof, h_tank = lhs_set$h_tank, 
                                      n_taps = lhs_set$n_taps, z = lhs_set$z,  h_0 = lhs_set$h_0,
                                      r_tank = lhs_set$r_tank, h_air = lhs_set$h_air, c_0 = lhs_set$c_0, 
                                      T_water_0 = lhs_set$T_water_0)
  
  modelRun(parameters = startParameters$parameters, yini = startParameters$yini, days = days, timestep =timestep)
}
print(Sys.time() - startTime)
rm(pb, opts)

# transpose outLHS to match dimension structure [monte carlo run, timestep, variable]
outLHS <- aperm(outLHS, c(3, 1, 2))

## calculate outLHS in 24h steps
outLHSdaily <- outLHS[ , seq(1, dim(outLHS)[2], by=60*60*24/timestep), ]
## calculate bottles per day based on outLHS (difference of n_Bottles in 24h steps)
bottlesPerDayLHS <- foreach(i = 1:n_lhs, .combine = rbind) %do% {
  diff(outLHSdaily[i, ,"n_Bottles"])
}

# calculate statistics over time----
skipper <- seq(1,dim(outLHS)[2], by=12) # use hourly values
simDays <- outLHS[1, skipper,"time"] /60/60/24

# calculate statistics over latin hypercube sample----
statistics.over.LHS <- foreach(i=1:n_lhs, .combine = rbind) %do% {
  c(mean.h = mean(outLHS[i, , "h"], na.rm = TRUE),
    mean.n_Bottles = mean(outLHS[i, , "n_Bottles"], na.rm = TRUE),
    mean.c = mean(outLHS[i, , "c"], na.rm = TRUE),
    mean.T_water = mean(outLHS[i, , "T_water"], na.rm = TRUE),
    mean.bottlesPerDay = mean(bottlesPerDayLHS[i, ], na.rm = TRUE)
    
    # h.sd = sd(outLHS[i, , "h"], na.rm = TRUE),
    # n_Bottles.sd = sd(outLHS[i, , "n_Bottles"], na.rm = TRUE),
    # c.sd = sd(outLHS[i, , "c"], na.rm = TRUE),
    # T_water.sd = sd(outLHS[i, , "T_water"], na.rm = TRUE),
    # bottlesPerDay.sd = sd(bottlesPerDayLHS[i, ], na.rm = TRUE)
  )
}

statistics.over.LHS <- as.data.frame(cbind(param_sets_lhs, statistics.over.LHS))

pairs(statistics.over.LHS, pch = 19, cex = 0.5, col = "deepskyblue", lower.panel=NULL)

png(filename = paste0("./plots/",version,"corChart.png"), width = 2000, height = 1500)
chart.Correlation(statistics.over.LHS, histogram=T, pch=19)
dev.off()

plot.ggpairs <- ggpairs(as.data.frame(statistics.over.LHS), 
        upper = list(continuous=ggally_cor),
        lower = list(continuous= wrap("smooth", colour="blue", size = 0.5, alpha = 0.25)),
        diag = list(continuous=wrap("densityDiag", color = "red"))) #+
        # scale_color_ipsum() +
        # scale_fill_ipsum() +
        # theme_ipsum_ps(grid="XY", axis="xy") + theme(legend.position="none")
ggsave2(paste0("./plots/",version,"plot.ggpairs.png"), plot = plot.ggpairs, width = 12, height = 8, units = "in")

stopCluster(cl)
rm(cl)
