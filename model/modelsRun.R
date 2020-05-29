modelRun <- function(parameters, yini, days, timestep = 1) {
  times <- seq(from = 0, to = 60*60*24*days, by = timestep)
  rainCurve <- rainCurveStochasticGumbel(simDays = days, dailyRainProb = parameters[["dailyRainProb"]], sdFactor = parameters[["sdFactor"]])
  ## ----model-------------------------------------------------------------------------------------------
  model <- function(t, y, parameters) {
    with(as.list(c(y, parameters)), {
      simHours <- t/60/60
      simDays <- floor(simHours/24) + 1
      Q_in <- rainCurve[simDays] *A_roof/24/60/60# [m^3/(m^2 * day)] -> [m^3/s]

      #----I/O micro-------------------------------------------------------------------------------------------
      dh <- (Q_in - Q_out)/(pi * r_tank^2)

      if (schedule(simHours) == "break") {
        # normal outflow (school break)
        if (h > 0) {
          #dQ_out <- n_taps * 2 * pi * r_taps^2 * sqrt(2 * g) * (h + z)^(1/2) - Q_out
          dQ_out <- g * n_taps * pi * r_taps^2 * (2 * g * (h + z))^(-1/2) * dh/timestep()
        } else {
          dQ_out <- - (Q_out + Q_in)/timestep()
        }
      } else if (schedule(simHours) == "breakStart"){
        # (start of school break()
        dQ_out <- n_taps * pi * r_taps^2 * sqrt(2 * g) * (h + z)^(1/2)/timestep()
      } else if (schedule(simHours) == "class" | schedule(simHours) == "freeTime") {
        # no outflow (school class)
        dQ_out <- - Q_out/timestep()
      }

      if (h >= h_tank & dh >= 0){
        dh <- 0
      }

      dn_Bottles <- Q_out/V_Bottle
      dV_out <- Q_out

      V <- max(h * r_tank^2 * pi, 0.0002)

      #----temperature-------------------------------------------------------------------------------------------
      T_air <- tempCurveAir(simHours)
      T_soil <- tempCurveSoil(simHours)

      R_ia_bottom    <- d_wall /(lambda_wall * pi * r_tank^2)
      R_ia_side_soil <- d_wall /(lambda_wall * 2 * pi * r_tank * h_soil)
      R_ia_side_air  <- d_wall /(lambda_wall * 2 * pi * r_tank * h_air)
      R_ia_top       <- d_wall /(lambda_wall * pi * r_tank^2)

      c_i_bottom     <- c_p_water * rho_water * pi * r_tank^2 * h_tank + c_p_wall * rho_wall * d_wall * pi * r_tank^2
      c_i_side_soil  <- c_p_water * rho_water * pi * r_tank^2 * h_tank + c_p_wall * rho_wall * d_wall * 2 * pi * r_tank * h_soil
      c_i_side_air   <- c_p_water * rho_water * pi * r_tank^2 * h_tank + c_p_wall * rho_wall * d_wall * 2 * pi * r_tank * h_air
      c_i_top        <- c_p_water * rho_water * pi * r_tank^2 * h_tank + c_p_wall * rho_wall * d_wall * pi * r_tank^2

      dT_water_conduction <- (T_soil-T_water)/(R_ia_bottom * c_i_bottom) +
        (T_soil-T_water)/(R_ia_side_soil * c_i_side_soil) +
        (T_air-T_water)/(R_ia_side_air * c_i_side_air) +
        (T_air-T_water)/(R_ia_top * c_i_top)

      dT_water_pollution <- ((Q_in * T_air + V * T_water - Q_out * T_water)/(V + Q_in - Q_out)) - T_water

      dT_water <- dT_water_conduction + dT_water_pollution

      if (abs(dT_water) > 10){
        dT_water <- 0
      }

      ##----bacterial growth-------------------------------------------------------------------------------------------
      k <- k_20 * Q_10^((T_water - T_20)/10)

      dc <- ((Q_in * c_in + V * c - Q_out *c)/(V + Q_in - Q_out)) - c + (k * c)
      #dc <- (k * c)

      if (abs(dc) > c/5){
        dc <- 0
      }

      # return everything
      return(list(c(dh, dQ_out, dn_Bottles, dV_out, dc, dT_water)))
    }
    )
  }

  ## -solver---------------------------------------------------------------------------------------------------
  out <- ode(func = model, y = yini, times = times, parms = parameters, method = "euler")

  return(out)
}



MC_process <- function(parameters, n_mc, yini){
  progress <- function(i) pb$tick()
  pb <- progress_bar$new(
    format = "[:bar] :current/:total runs | elapsed::elapsed",
    total = n_mc, clear = FALSE)
  opts <- list(progress=progress)
  bind3d <- function(...) abind(..., along = 3)

  outMC <-foreach(i=1:n_mc, .options.snow=opts, .packages = c("deSolve", "powdist"), .combine = bind3d, .export = ls(globalenv())) %dopar% {
    modelRun(parameters = parameters, yini = yini, days = days, timestep =timestep)
  }
  print(Sys.time() - startTime)
  rm(pb, opts)

  # transpose outMC to match dimension structure [monte carlo run, timestep, variable]
  outMC <- aperm(outMC, c(3, 1, 2))
  
  ## calculate outMC in 24h steps
  outMCdaily <- outMC[ , seq(1, dim(outMC)[2], by=60*60*24/timestep), ]
  ## calculate bottles per day based on outMC (difference of n_Bottles in 24h steps)
  bottlesPerDayMC <- foreach(i = 1:n_mc, .combine = rbind) %do% {
    diff(outMCdaily[i, ,"n_Bottles"])
  }

  # calculate statistics over monte carlo runs
  statistics.over.MC <- c(h = mean(outMC[, , "h"], na.rm = TRUE),
                          n_Bottles = mean(outMC[, , "n_Bottles"], na.rm = TRUE),
                          c = mean(outMC[, , "c"], na.rm = TRUE),
                          T_water = mean(outMC[, , "T_water"], na.rm = TRUE),
                          bottlesPerDay = mean(bottlesPerDayMC[, ], na.rm = TRUE)

                          # ci95.low.h = quantile(outMC[, , "h"], probs = c(0.025), na.rm = TRUE)[[1]],
                          # ci95.low.n_Bottles = quantile(outMC[, , "n_Bottles"], probs = c(0.025), na.rm = TRUE)[[1]],
                          # ci95.low.c = quantile(outMC[, , "c"], probs = c(0.025), na.rm = TRUE)[[1]],
                          # ci95.low.T_water = quantile(outMC[, , "T_water"], probs = c(0.025), na.rm = TRUE)[[1]],
                          # ci95.low.bottlesPerDay = quantile(bottlesPerDayMC[, ], probs = c(0.025), na.rm = TRUE)[[1]],
                          # 
                          # ci95.up.h = quantile(outMC[, , "h"], probs = c(0.975), na.rm = TRUE)[[1]],
                          # ci95.up.n_Bottles = quantile(outMC[, , "n_Bottles"], probs = c(0.975), na.rm = TRUE)[[1]],
                          # ci95.up.c = quantile(outMC[, , "c"], probs = c(0.975), na.rm = TRUE)[[1]],
                          # ci95.up.T_water = quantile(outMC[, , "T_water"], probs = c(0.975), na.rm = TRUE)[[1]],
                          # ci95.up.bottlesPerDay = quantile(bottlesPerDayMC[, ], probs = c(0.975), na.rm = TRUE)[[1]],
                          # 
                          # h.sd = sd(outMC[, , "h"], na.rm = TRUE),
                          # n_Bottles.sd = sd(outMC[, , "n_Bottles"], na.rm = TRUE),
                          # c.sd = sd(outMC[, , "c"], na.rm = TRUE),
                          # T_water.sd = sd(outMC[, , "T_water"], na.rm = TRUE),
                          # bottlesPerDay.sd = sd(bottlesPerDayMC[, ], na.rm = TRUE)
                          )

  return(statistics.over.MC)
}
