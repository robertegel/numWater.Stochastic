## ----setup, include=FALSE----------------------------------------------------------------------------
# if not installed yet, install required packages
list.of.packages <- c("ggplot2", "deSolve", "progress", "parallel", "doSNOW", "cowplot", "abind", "tidyr", "tgp", "hrbrthemes", "powdist")
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
# library(GGally)

# library for LHS sampling
library(tgp)

version <- "allModelsVersion3.2"

# source external file to define helper functions ----
# for schedule, temperature and rain curve, parameters
source("./schedules.climate.parameters.R")
source("./modelsRun.R")
source("./stochastics.R")

## -run models---------------------------------------------------------------------------------------------------
days <- 365
timestep <- 5*60

startParameters <- defineParameters(dailyRainProb = 0.20, sdFactor = 1/10)

numCores <- detectCores()
if(!exists("cl")) cl <- makeCluster(numCores)
registerDoSNOW(cl)

n_mc <- 512
version <- paste0(version, ".", days, "days.n_mc=", n_mc)

progress <- function(i) pb$tick()
pb <- progress_bar$new(
  format = "[:bar] :current/:total runs | elapsed::elapsed",
  total = n_mc, clear = FALSE)
opts <- list(progress=progress)
bind3d <- function(...) abind(..., along = 3)

startTime <- Sys.time()
outMC <-foreach(i=1:n_mc, .options.snow=opts, .packages = c("deSolve", "powdist"), .combine = bind3d) %dopar% {
  modelRun(parameters = startParameters$parameters, yini = startParameters$yini, days = days, timestep =timestep)
}
print(Sys.time() - startTime)
rm(pb, opts)

# calculate deterministic model (as reference)
startParameters <- defineParameters(dailyRainProb = 1.0, sdFactor = 0.0) 
outDet <- modelRun(parameters = startParameters$parameters, yini = startParameters$yini, days = days, timestep =timestep)

# transpose outMC to match dimension structure [monte carlo run, timestep, variable]
outMC <- aperm(outMC, c(3, 1, 2))

## calculate outMC/outDet in 24h steps
outMCdaily <- outMC[ , seq(1, dim(outMC)[2], by=60*60*24/timestep), ]
outDetDaily <- outDet[seq(1, dim(outDet)[1], by=60*60*24/timestep), ]
outDetDaily <- as.data.frame(outDetDaily)

## calculate bottles per day based on outMC/outDet (difference of n_Bottles in 24h steps)
bottlesPerDayMC <- foreach(i = 1:n_mc, .combine = rbind) %do% {
  diff(outMCdaily[i, ,"n_Bottles"])
}
bottlesPerDayDet <- diff(outDetDaily[ ,"n_Bottles"])

# calculate statistics over time----
skipper <- seq(1,dim(outMC)[2], by=12) # use hourly values
simDays <- outMC[1, skipper,"time"] /60/60/24
statistics.over.time <- c()

statistics.over.time <- foreach(i=skipper, .combine = rbind) %do% {
  c(mean.h = mean(outMC[, i, "h"], na.rm = TRUE),
                    mean.n_Bottles = mean(outMC[, i, "n_Bottles"], na.rm = TRUE),
                    mean.c = mean(outMC[, i, "c"], na.rm = TRUE),
                    mean.T_water = mean(outMC[, i, "T_water"], na.rm = TRUE),
                    ci95.low.h = quantile(outMC[, i, "h"], probs = c(0.025), na.rm = TRUE)[[1]],
                    ci95.low.n_Bottles = quantile(outMC[, i, "n_Bottles"], probs = c(0.025), na.rm = TRUE)[[1]],
                    ci95.low.c = quantile(outMC[, i, "c"], probs = c(0.025), na.rm = TRUE)[[1]],
                    ci95.low.T_water = quantile(outMC[, i, "T_water"], probs = c(0.025), na.rm = TRUE)[[1]],
                    ci95.up.h = quantile(outMC[, i, "h"], probs = c(0.975), na.rm = TRUE)[[1]],
                    ci95.up.n_Bottles = quantile(outMC[, i, "n_Bottles"], probs = c(0.975), na.rm = TRUE)[[1]],
                    ci95.up.c = quantile(outMC[, i, "c"], probs = c(0.975), na.rm = TRUE)[[1]],
                    ci95.up.T_water = quantile(outMC[, i, "T_water"], probs = c(0.975), na.rm = TRUE)[[1]],
                    h.sd = sd(outMC[, i, "h"], na.rm = TRUE),
                    n_Bottles.sd = sd(outMC[, i, "n_Bottles"], na.rm = TRUE),
                    c.sd = sd(outMC[, i, "c"], na.rm = TRUE),
                    T_water.sd = sd(outMC[, i, "T_water"], na.rm = TRUE)
                    )
}
statistics.over.time <- as.data.frame(statistics.over.time)

statistics.over.days <- c()
for (i in 1:dim(outMCdaily)[2]) {
  tmp <- c(mean.h = mean(outMCdaily[, i, "h"], na.rm = TRUE),
           mean.n_Bottles = mean(outMCdaily[, i, "n_Bottles"], na.rm = TRUE),
           mean.c = mean(outMCdaily[, i, "c"], na.rm = TRUE),
           mean.T_water = mean(outMCdaily[, i, "T_water"], na.rm = TRUE),

           ci95.low.h = quantile(outMCdaily[, i, "h"], probs = c(0.025), na.rm = TRUE)[[1]],
           ci95.low.n_Bottles = quantile(outMCdaily[, i, "n_Bottles"], probs = c(0.025), na.rm = TRUE)[[1]],
           ci95.low.c = quantile(outMCdaily[, i, "c"], probs = c(0.025), na.rm = TRUE)[[1]],
           ci95.low.T_water = quantile(outMCdaily[, i, "T_water"], probs = c(0.025), na.rm = TRUE)[[1]],

           ci95.up.h = quantile(outMCdaily[, i, "h"], probs = c(0.975), na.rm = TRUE)[[1]],
           ci95.up.n_Bottles = quantile(outMCdaily[, i, "n_Bottles"], probs = c(0.975), na.rm = TRUE)[[1]],
           ci95.up.c = quantile(outMCdaily[, i, "c"], probs = c(0.975), na.rm = TRUE)[[1]],
           ci95.up.T_water = quantile(outMCdaily[, i, "T_water"], probs = c(0.975), na.rm = TRUE)[[1]],

           h.sd = sd(outMCdaily[, i, "h"], na.rm = TRUE),
           n_Bottles.sd = sd(outMCdaily[, i, "n_Bottles"], na.rm = TRUE),
           c.sd = sd(outMCdaily[, i, "c"], na.rm = TRUE),
           T_water.sd = sd(outMCdaily[, i, "T_water"], na.rm = TRUE)
  )
  statistics.over.days <- rbind(statistics.over.days, tmp)
  rm(i, tmp)
}
statistics.over.days <- as.data.frame(statistics.over.days)

statistics.bottlesPerDay = c()
for (i in 1:dim(bottlesPerDayMC)[2]) {
  tmp <- c(mean.bottlesPerDay = mean(bottlesPerDayMC[, i], na.rm = TRUE),
           ci95.low.bottlesPerDay = quantile(bottlesPerDayMC[, i], probs = c(0.025), na.rm = TRUE)[[1]],
           ci95.up.bottlesPerDay = quantile(bottlesPerDayMC[, i], probs = c(0.975), na.rm = TRUE)[[1]],
           sd.bottlesPerDay = sd(bottlesPerDayMC[, i], na.rm = TRUE)
  )
  statistics.bottlesPerDay <- rbind(statistics.bottlesPerDay, tmp)
  rm(i, tmp)
}
statistics.bottlesPerDay <- as.data.frame(statistics.bottlesPerDay)

{# statistic plots for each output with mean and 95% CI over time----
  plot.h <- ggplot(statistics.over.days, aes(x = 1:nrow(statistics.over.days))) +
    geom_line(size = 0.5, aes(y=mean.h, color = "mean")) +
    geom_line(size = 0.5, aes(y=ci95.low.h, color = "95% confidence interval")) +
    geom_line(size = 0.5, aes(y=ci95.up.h, color = "95% confidence interval")) +
    geom_line(size = 0.5, aes(y=outDetDaily$h, color = "deterministic")) +
    xlab("simulation time in days") +
    ylab("h [m]") +
    scale_color_manual(name= "", values=c("grey", "darkblue", "black")) +
    theme_ipsum_ps(grid="XY", axis="xy") + theme(legend.position="none")

  plot.T_water <- ggplot(statistics.over.days, aes(1:nrow(statistics.over.days))) +
    geom_line(size = 0.5, aes(y=mean.T_water, color = "mean")) +
    geom_line(size = 0.5, aes(y=ci95.low.T_water, color = "95% confidence interval")) +
    geom_line(size = 0.5, aes(y=ci95.up.T_water, color = "95% confidence interval")) +
    geom_line(size = 0.5, aes(y=outDetDaily$T_water, color = "deterministic")) +
    xlab("simulation time in days") +
    ylab("T_water [°C]") +
    scale_color_manual(name= "", values=c("grey", "darkblue", "black")) +
    theme_ipsum_ps(grid="XY", axis="xy") + theme(legend.position="none")

  plot.c <- ggplot(statistics.over.days, aes(1:nrow(statistics.over.days))) +
    geom_line(size = 0.5, aes(y=mean.c, color = "mean")) +
    geom_line(size = 0.5, aes(y=ci95.low.c, color = "95% confidence interval")) +
    geom_line(size = 0.5, aes(y=ci95.up.c, color = "95% confidence interval")) +
    geom_line(size = 0.5, aes(y=outDetDaily$c, color = "deterministic")) +
    xlab("simulation time in days") +
    ylab("bacteria concentration [n/m^3]") +
    scale_color_manual(name= "", values=c("grey", "darkblue", "black")) +
    theme_ipsum_ps(grid="XY", axis="xy") + theme(legend.position="bottom")

  plot.bottlesPerDay <- ggplot(statistics.bottlesPerDay, aes(x = 1:nrow(statistics.bottlesPerDay))) +
    geom_line(size = 0.5, aes(y=mean.bottlesPerDay, color = "mean")) +
    geom_line(size = 0.5, aes(y=ci95.low.bottlesPerDay, color = "95% confidence interval")) +
    geom_line(size = 0.5, aes(y=ci95.up.bottlesPerDay, color = "95% confidence interval")) +
    geom_line(size = 0.5, aes(y=bottlesPerDayDet, color = "deterministic")) +
    xlab("simulation time in days") +
    ylab("number of bottles") +
    scale_color_manual(name= "", values=c("grey", "darkblue", "black"))  +
    theme_ipsum_ps(grid="XY", axis="xy") + theme(legend.position="bottom")

  plotgrid <- cowplot::plot_grid(plot.h, plot.T_water, plot.c, plot.bottlesPerDay)
  title <- ggdraw() +
    draw_label(paste0(version,""))
  plots.over.time <- plot_grid(title, plotgrid,  ncol = 1,  rel_heights = c(0.05, 1))
  ggsave2(paste0("./plots/",version,".over.time.png"), plot = plotgrid, width = 12, height = 8, units = "in")
  rm(plot.h, plot.c, plot.T_water, plot.bottlesPerDay, plotgrid)
}

plots.over.time

# calculate statistics over monte carlo runs----
statistics.over.MC <- c(mean.h = mean(outMC[, , "h"], na.rm = TRUE),
                        mean.n_Bottles = mean(outMC[, , "n_Bottles"], na.rm = TRUE),
                        mean.c = mean(outMC[, , "c"], na.rm = TRUE),
                        mean.T_water = mean(outMC[, , "T_water"], na.rm = TRUE),
                        mean.bottlesPerDay = mean(bottlesPerDayMC[, ], na.rm = TRUE),

                        ci95.low.h = quantile(outMC[, , "h"], probs = c(0.025), na.rm = TRUE)[[1]],
                        ci95.low.n_Bottles = quantile(outMC[, , "n_Bottles"], probs = c(0.025), na.rm = TRUE)[[1]],
                        ci95.low.c = quantile(outMC[, , "c"], probs = c(0.025), na.rm = TRUE)[[1]],
                        ci95.low.T_water = quantile(outMC[, , "T_water"], probs = c(0.025), na.rm = TRUE)[[1]],
                        ci95.low.bottlesPerDay = quantile(bottlesPerDayMC[, ], probs = c(0.025), na.rm = TRUE)[[1]],

                        ci95.up.h = quantile(outMC[, , "h"], probs = c(0.975), na.rm = TRUE)[[1]],
                        ci95.up.n_Bottles = quantile(outMC[, , "n_Bottles"], probs = c(0.975), na.rm = TRUE)[[1]],
                        ci95.up.c = quantile(outMC[, , "c"], probs = c(0.975), na.rm = TRUE)[[1]],
                        ci95.up.T_water = quantile(outMC[, , "T_water"], probs = c(0.975), na.rm = TRUE)[[1]],
                        ci95.up.bottlesPerDay = quantile(bottlesPerDayMC[, ], probs = c(0.975), na.rm = TRUE)[[1]],

                        h.sd = sd(outMC[, , "h"], na.rm = TRUE),
                        n_Bottles.sd = sd(outMC[, , "n_Bottles"], na.rm = TRUE),
                        c.sd = sd(outMC[, , "c"], na.rm = TRUE),
                        T_water.sd = sd(outMC[, , "T_water"], na.rm = TRUE),
                        bottlesPerDay.sd = sd(bottlesPerDayMC[, ], na.rm = TRUE)
                        )

statistics.over.MC.dist <- c()
statistics.over.MC.dist <- foreach(i=1:n_mc, .combine = rbind) %do% {
  c(h = mean(outMC[i, , "h"], na.rm = TRUE),
    #n_Bottles = mean(outMC[i, , "n_Bottles"], na.rm = TRUE),
    c = mean(outMC[i, , "c"], na.rm = TRUE),
    T_water = mean(outMC[i, , "T_water"], na.rm = TRUE),
    bottlesPerDay = mean(bottlesPerDayMC[i, ], na.rm = TRUE)
    )
}
statistics.over.MC.dist <- as.data.frame(statistics.over.MC.dist)

statistics.over.MC.dist <- gather(statistics.over.MC.dist, "h", "c", "T_water", "bottlesPerDay",
               key = "output_variable", value = "mean")

plot.MC.dist <- ggplot(statistics.over.MC.dist, aes(mean, y = ..density.., fill = output_variable)) +
  geom_histogram(bins = 10) +
  geom_density(alpha = 0.0, linetype="dotted") +
  facet_wrap(vars(output_variable), scales="free") +
  scale_color_ipsum() +
  scale_fill_ipsum() +
  theme_ipsum_ps(grid="XY", axis="xy") + theme(legend.position="none")
ggsave2(paste0("./plots/",version,"MC.dist.png"), plot = plot.MC.dist, width = 12, height = 8, units = "in")
plot.MC.dist

stopCluster(cl)
rm(cl)
