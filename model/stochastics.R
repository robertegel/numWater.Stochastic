# library for gumbel distribution
library(powdist)
library(ggplot2)
library(hrbrthemes)

rainCurveStochasticNorm <- function(simDays, dailyRainProb, sdFactor) {
  # calculating mean rain precipation per day from monthly data (mean daily amount in each month)
  pm <- c(124, 127, 152, 181, 119, 31, 20, 47, 119, 153, 159, 132)/1000
  pd <- pm/c(31, 28, 31, 30, 31, 30, 31, 30, 31, 30, 31, 30)
  months <- seq(1,12,1)

  # generate spline, set to periodic to avoid gaps at new years
  pdSpline <- spline(months, pd, n = 365, method = "periodic")

  # cumulated amount of rain should remain the same as before
  # therefore increasing intensity for days when there is rain
  rainMeanPrecipitation <- pdSpline$y/dailyRainProb
  rainPrecipitation <- c()

  # calculate random daily rain intensity
  for (i in 1:simDays){
    # rainMeanIntensity has only 365 data points, therefore introduce new variable, that counts day of the year
    day <- i %% 365
    if (day==0) day <- 365

    # calculate rain intensity with normal distribution and mean rain intensity as given by spline
    # max(0, ...) -> aviod negative values for rain intensity
    rainPrecipitation[i] <- max(0, rnorm(1, mean = rainMeanPrecipitation[day], sd = mean(rainMeanPrecipitation)*sdFactor))
  }

  # will it rain at all? generate logical vector of rainy days
  rainBool <- as.logical(rbinom(simDays, 1, dailyRainProb))

  # multiplicate rain intensity and rainy day vector
  # if rainy day == TRUE -> then rain = rainPrecipitation
  # if rainy day == FALSE -> then rain = 0
  rain <- rainPrecipitation * rainBool

  # plot(rain, type = "l")
  return(rain)
}

# {# playing around with gumbel distribution
#   ## prerequisites
#   sdFactor <- 1/20
#   dailyRainProb <- 1.0
#   # Euler–Mascheroni constant
#   gamma <- 0.5772
# 
#   # calculating mean rain precipitation per day from monthly data (mean daily amount in each month)
#   pm <- c(124, 127, 152, 181, 119, 31, 20, 47, 119, 153, 159, 132)/1000
#   pd <- pm/c(31, 28, 31, 30, 31, 30, 31, 30, 31, 30, 31, 30)
#   months <- seq(1,12,1)
# 
#   # generate spline, set to periodic to avoid gaps at new years
#   pdSpline <- spline(months, pd, n = 365, method = "periodic")
# 
#   # cumulated amount of rain should remain the same as before
#   # therefore increasing intensity for days when there is rain
#   rainMeanPrecipitation <- pdSpline$y/dailyRainProb
# 
#   ## calculate metrics
#   gumbelSd <-  mean(rainMeanPrecipitation)*sdFactor
#   gumbelMu <- 0
# 
#   ## calculate gumbel parameters
#   gumbelSigma <- sqrt(gumbelSd^2/pi^2 * 6)
# 
#   pgumbel(gumbelMu, mu = gumbelMu, sigma = gumbelSigma)
#   xLimits <- qgumbel(p = c(0.0001, 0.99999), mu = gumbelMu, sigma = gumbelSigma)
#   sequence <- seq(xLimits[1],xLimits[2], by = 0.00001)
#   plot(sequence, dgumbel(x = sequence, mu = gumbelMu, sigma = gumbelSigma), type = "l")
#   lines(c(gumbelMu, gumbelMu), c(0, 3000))
# 
#   hist.gumbel.rain.variation <- ggplot()+
#     geom_line(aes(x = sequence, y=dgumbel(x = sequence, mu = gumbelMu, sigma = gumbelSigma), color = "distribution")) +
#     geom_vline(aes(xintercept = gumbelMu, color = "mean")) +
#     ylab("density") + xlab("variation from mean daily rain") +
#     scale_color_manual(name= "", values=c("black", "darkgrey"))  +
#     theme_ipsum_ps(grid="XY", axis="xy") +
#     theme(legend.position="bottom")
#   ggsave2(paste0("./plots/hist.gumbel.rain.variation.png"), plot = hist.gumbel.rain.variation, width = 12/1.5, height = 8/1.5, units = "in")
# }

rainCurveStochasticGumbel <- function(simDays, dailyRainProb, sdFactor) {
  # calculating mean rain precipation per day from monthly data (mean daily amount in each month)
  pm <- c(124, 127, 152, 181, 119, 31, 20, 47, 119, 153, 159, 132)/1000
  pd <- pm/c(31, 28, 31, 30, 31, 30, 31, 30, 31, 30, 31, 30)
  months <- seq(1,12,1)

  # generate spline, set to periodic to avoid gaps at new years
  pdSpline <- spline(months, pd, n = 365, method = "periodic")

  # cumulated amount of rain should remain the same as before
  # therefore increasing intensity for days when there is rain
  rainMeanPrecipitation <- pdSpline$y/dailyRainProb
  rainPrecipitation <- c()

  ## calculate gumbel parameters
  gumbelSd <-  mean(rainMeanPrecipitation)*sdFactor
  gumbelSigma <- sqrt(gumbelSd^2/pi^2 * 6)

  # calculate random daily rain intensity
  for (i in 1:simDays){
    # rainMeanIntensity has only 365 data points, therefore introduce new variable, that counts day of the year
    day <- i %% 365
    if (day==0) day <- 365

    # calculate rain intensity with normal distribution and mean rain intensity as given by spline
    # max(0, ...) -> aviod negative values for rain intensity
    rainPrecipitation[i] <- max(0, rgumbel(1, mu = rainMeanPrecipitation[day], sigma = gumbelSigma))
  }

  # will it rain at all? generate logical vector of rainy days
  rainBool <- as.logical(rbinom(simDays, 1, dailyRainProb))

  # multiplicate rain intensity and rainy day vector
  # if rainy day == TRUE -> then rain = rainPrecipitation
  # if rainy day == FALSE -> then rain = 0
  rain <- rainPrecipitation * rainBool

  # plot(rain, type = "l")
  return(rain)
}

# {# plots for examplary rain curves
#   days <- 365
#   rain.det <- rainCurveStochasticGumbel(simDays = days, dailyRainProb = 1.0, sdFactor = 0)
#   rainCurve.det <- ggplot()+
#     geom_point(aes(x = 1:days, y =  rain.det, color = "distribution")) +
#     ylab("rain precipation in l/m^2") + xlab("time (days)") +
#     scale_color_manual(name= "", values=c("black", "darkgrey"))  +
#     theme_ipsum_ps(grid="XY", axis="xy") +
#     theme(legend.position="none") +
#     ggtitle("Deterministic rain curve", subtitle = "")
# 
#   rain.binom <- rainCurveStochasticGumbel(simDays = days, dailyRainProb = 0.2, sdFactor = 0)
#   rainCurve.binom <- ggplot()+
#     geom_point(aes(x = 1:days, y =  rain.binom, color = "distribution")) +
#     ylab("rain precipation in l/m^2") + xlab("time (days)") +
#     scale_color_manual(name= "", values=c("black", "darkgrey"))  +
#     theme_ipsum_ps(grid="XY", axis="xy") +
#     theme(legend.position="none") +
#     ggtitle("Stochastic rain curve", subtitle = "binomial distribution included (determines rainy days)")
# 
#   rain.gumbel <- rainCurveStochasticGumbel(simDays = days, dailyRainProb = 1.0, sdFactor = 1/10)
#   rainCurve.gumbel <- ggplot()+
#     geom_point(aes(x = 1:days, y =  rain.gumbel, color = "distribution")) +
#     ylab("rain precipation in l/m^2") + xlab("time (days)") +
#     scale_color_manual(name= "", values=c("black", "darkgrey"))  +
#     theme_ipsum_ps(grid="XY", axis="xy") +
#     theme(legend.position="none") +
#     ggtitle("Stochastic rain curve", subtitle = "gumbel distribution included (determines rain intensity)")
# 
#   rain.binom.gumbel <- rainCurveStochasticGumbel(simDays = days, dailyRainProb = 0.2, sdFactor = 1/10)
#   rainCurve.binom.gumbel <- ggplot()+
#     geom_point(aes(x = 1:days, y =  rain.binom.gumbel, color = "distribution")) +
#     ylab("rain precipation in l/m^2") + xlab("time (days)") +
#     scale_color_manual(name= "", values=c("black", "darkgrey"))  +
#     theme_ipsum_ps(grid="XY", axis="xy") +
#     theme(legend.position="none") +
#     ggtitle("Stochastic rain curve", subtitle = "both binomial and gumbel distributions (used in model)")
# 
#   rainCurves <- plot_grid(rainCurve.det, rainCurve.binom, rainCurve.gumbel, rainCurve.binom.gumbel)
#   ggsave2(paste0("./plots/rainCurves.png"), plot = rainCurves, width = 12, height = 8, units = "in")
# }
