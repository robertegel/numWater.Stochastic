## ----setup, include=FALSE----------------------------------------------------------------------------
# if not installed yet, install required packages
list.of.packages <- c("ggplot2", "deSolve", "progress", "parallel", "doSNOW", "cowplot", "abind", "tidyr", "tgp", "hrbrthemes", "powdist")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

rm(list=ls()[-(which(ls() == "cl" | ls() == "listfiles"))])

library(hrbrthemes)
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
# library(GGally)

# library for LHS sampling
library(tgp)

version <- "allModelsVersion3.2.sens.material"

# source external file to define helper functions ----
# for schedule, temperature and rain curve, parameters
source("./schedules.climate.parameters.R")
source("./modelsRun.R")
source("./stochastics.R")

## -run models---------------------------------------------------------------------------------------------------
days <- 365
timestep <- 5*60

numCores <- detectCores()
if(!exists("cl")) cl <- makeCluster(numCores)
registerDoSNOW(cl)

n_mc <- 128
version <- paste0(version, ".", days, "days.n_mc=", n_mc)

variationsmaterial <- c("concrete", "polyethylen")

# run simulations for all variations of material
MC_result <- c()
startTime <- Sys.time()
for (i in 1:length(variationsmaterial)) {
  print(paste0("Processing variation ", i, " of ", length(variationsmaterial), " for material"))

  startParameters <- defineParameters(dailyRainProb = 0.20, sdFactor = 1/10, material = variationsmaterial[i])

  parameters <- startParameters$parameters
  yini <- startParameters$yini

  tmp <- MC_process(parameters = parameters, n_mc = n_mc, yini = yini)
  MC_result <- cbind(MC_result, c(material = variationsmaterial[i], tmp))
}
MC_result <- as.data.frame(t(MC_result))

{
  plot.h <- ggplot(MC_result) +
    geom_point(aes(x = material, y = h)) +
    scale_color_ipsum() +
    scale_fill_ipsum() +
    theme_ipsum_ps(grid="XY", axis="xy") + theme(legend.position="none")
  plot.h

  plot.bottlesPerDay <- ggplot(MC_result) +
    geom_point(aes(x = material, y = bottlesPerDay)) +
    scale_color_ipsum() +
    scale_fill_ipsum() +
    theme_ipsum_ps(grid="XY", axis="xy") + theme(legend.position="none")
  plot.bottlesPerDay

  plot.T_water <- ggplot(MC_result) +
    geom_point(aes(x = material, y = T_water)) +
    scale_color_ipsum() +
    scale_fill_ipsum() +
    theme_ipsum_ps(grid="XY", axis="xy") + theme(legend.position="none")
  plot.T_water

  plot.c <- ggplot(MC_result) +
    geom_point(aes(x = material, y = c)) +
    scale_color_ipsum() +
    scale_fill_ipsum() +
    theme_ipsum_ps(grid="XY", axis="xy") + theme(legend.position="none")
  plot.c

  plotgrid <- cowplot::plot_grid(plot.h, plot.T_water, plot.c, plot.bottlesPerDay)
  title <- ggdraw() +
    draw_label(paste0(version,""))
  plots.over.time <- plot_grid(title, plotgrid,  ncol = 1,  rel_heights = c(0.05, 1))
  ggsave2(paste0("./plots/",version,".png"), plot = plots.over.time, width = 12, height = 8, units = "in")
  rm(plot.h, plot.c, plot.T_water, plot.bottlesPerDay, plotgrid)
}

plots.over.time

stopCluster(cl)
rm(cl)
