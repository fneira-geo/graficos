# =============================================================================
# Quantile Delta Mapping (QDM) v2 — Monthly Climate Bias Correction
# Cannon et al. (2015), Clim. Dyn. doi:10.1007/s00382-015-2552-3
#
# Design constraints for this implementation:
#   - ERA5: 30 years (1990–2020), full period
#   - Obs:  10–20 years per station (irregular overlap with ERA5)
#   - Calibration = obs-ERA5 overlap; application = full ERA5 30yr
#   - Precipitation: multiplicative QDM (ratio delta)
#   - by_month = TRUE: separate QDM per calendar month (seasonal bias structure)
#   - n_q adapts to available calibration data per month
#   - Tail extrapolation: log-linear above max calibration quantile
#   - Structural zeros: separate wet-fraction treatment (rare for monthly totals)
#   - Evaluation: Leave-One-Year-Out CV (LOYO-CV) since train/test split
#     is not viable with 10–20 years of obs
# =============================================================================


# -----------------------------------------------------------------------------
# INTERNAL: tail-aware quantile interpolation
# -----------------------------------------------------------------------------
# Replaces approx(..., rule=2) for the q_obs / q_modc lookups.
# For tau beyond the calibration range:
#   - type = "ratio"  → log-linear extrapolation (preserves multiplicative structure)
#   - type = "difference" → linear extrapolation
#
# probs:  probability nodes (length n_q+2, including 0 and 1)
# q_vals: quantile values at probs
# tau:    target probabilities (may exceed [min(probs), max(probs)] marginally)
# Returns: interpolated/extrapolated quantile values
# -----------------------------------------------------------------------------
.interp_quantile <- function(probs, q_vals, tau, type = "ratio") {

  n  <- length(probs)
  # Interior interpolation (rule=1 → NA outside range, filled below)
  out <- approx(probs, q_vals, xout = tau, method = "linear", rule = 1L)$y

  above <- is.na(out) & tau > probs[n]
  below <- is.na(out) & tau < probs[1L]

  if (any(above)) {
    if (type == "ratio") {
      # Log-linear extrapolation using last two nodes (positive values only)
      q_hi  <- pmax(q_vals[n],    .Machine$double.eps)
      q_hi1 <- pmax(q_vals[n-1L], .Machine$double.eps)
      slope_log <- (log(q_hi) - log(q_hi1)) / (probs[n] - probs[n-1L])
      out[above] <- exp(log(q_hi) + slope_log * (tau[above] - probs[n]))
    } else {
      slope <- (q_vals[n] - q_vals[n-1L]) / (probs[n] - probs[n-1L])
      out[above] <- q_vals[n] + slope * (tau[above] - probs[n])
    }
  }

  if (any(below)) {
    if (type == "ratio") {
      q_lo  <- pmax(q_vals[1L],  .Machine$double.eps)
      q_lo2 <- pmax(q_vals[2L],  .Machine$double.eps)
      slope_log <- (log(q_lo2) - log(q_lo)) / (probs[2L] - probs[1L])
      out[below] <- exp(log(q_lo) + slope_log * (tau[below] - probs[1L]))
      out[below] <- pmax(out[below], 0)
    } else {
      slope <- (q_vals[2L] - q_vals[1L]) / (probs[2L] - probs[1L])
      out[below] <- q_vals[1L] + slope * (tau[below] - probs[1L])
    }
  }

  out
}


# -----------------------------------------------------------------------------
# 1. CORE QDM
# -----------------------------------------------------------------------------
# obs_cal       observed values in calibration period        (NAs allowed)
# mod_cal       ERA5 values in calibration period            (NAs allowed)
# mod_app       ERA5 values to correct (full application period)
# type          "ratio" (precip) | "difference" (temp)
# n_q           quantile nodes; adaptive default computed in qdm_station
# min_val       floor after correction (0 for precip)
# zero_threshold structural zero threshold for obs (set corrected < thr to 0)
#
# Returns: corrected vector same length as mod_app; NAs where mod_app is NA.
# -----------------------------------------------------------------------------
qdm_correct <- function(obs_cal, mod_cal, mod_app,
                        type            = "ratio",
                        n_q             = 30L,
                        min_val         = 0,
                        zero_threshold  = 0) {

  obs_c <- obs_cal[is.finite(obs_cal)]
  mod_c <- mod_cal[is.finite(mod_cal)]
  mod_a <- mod_app[is.finite(mod_app)]

  if (length(obs_c) < 4L || length(mod_c) < 4L) {
    warning("qdm_correct: < 4 finite cal values; returning raw mod_app")
    return(mod_app)
  }

  # Degenerate distributions (e.g., monthly precip with all-zero series in a
  # dry month) make `quantile()` produce duplicates that `approx()` cannot
  # interpolate. Fall back to a mean-based correction in that case.
  if (length(unique(obs_c)) < 2L ||
      length(unique(mod_c)) < 2L ||
      length(unique(mod_a)) < 2L) {
    corrected <- if (type == "ratio") {
      r <- mean(obs_c) / max(mean(mod_c), .Machine$double.eps)
      pmax(mod_app * r, min_val)
    } else {
      mod_app + (mean(obs_c) - mean(mod_c))
    }
    if (zero_threshold > 0)
      corrected[is.finite(corrected) & corrected < zero_threshold] <- 0
    corrected[!is.finite(mod_app)] <- NA_real_
    return(corrected)
  }

  # Clamp n_q to what calibration data can support
  n_q  <- min(n_q, length(obs_c) - 1L, length(mod_c) - 1L)
  probs <- seq(0, 1, length.out = n_q + 2L)

  q_obs  <- quantile(obs_c, probs, type = 8L, names = FALSE)
  q_modc <- quantile(mod_c, probs, type = 8L, names = FALSE)
  q_moda <- quantile(mod_a, probs, type = 8L, names = FALSE)

  # τ_t: rank of each mod_app value within the application-period distribution
  # rule=2 here is fine: q_moda IS from mod_app, so no extrapolation needed
  tau <- approx(q_moda, probs, xout = mod_app, method = "linear", rule = 2L)$y

  # Obs and cal-model quantiles at τ with tail extrapolation
  q_obs_tau  <- .interp_quantile(probs, q_obs,  tau, type)
  q_modc_tau <- .interp_quantile(probs, q_modc, tau, type)

  corrected <- if (type == "ratio") {
    delta <- mod_app / pmax(q_modc_tau, .Machine$double.eps)
    pmax(q_obs_tau * delta, min_val)
  } else {
    q_obs_tau + (mod_app - q_modc_tau)
  }

  # Structural zeros
  if (zero_threshold > 0)
    corrected[is.finite(corrected) & corrected < zero_threshold] <- 0

  corrected[!is.finite(mod_app)] <- NA_real_
  corrected
}


# -----------------------------------------------------------------------------
# 2. STATION-LEVEL QDM
# -----------------------------------------------------------------------------
# obs / mod     numeric vectors (monthly, same length, aligned dates)
# dates         Date vector (or coercible)
# cal_mask      logical, length = length(obs)
#                 NULL  → auto: calibration = rows where obs is finite (overlap)
#                 logical → user-supplied mask (e.g. specific date range)
# by_month      logical; TRUE = separate QDM per calendar month (recommended)
# n_q           integer; 0 = adaptive (floor(0.8 × n_cal_per_month))
# min_n_cal     minimum finite paired obs–mod values per month to attempt QDM;
#               months with fewer fall back to raw ERA5
# ...           forwarded to qdm_correct (type, min_val, zero_threshold)
#
# Returns: corrected ERA5 vector (full length, all 30 years); NAs where mod=NA.
# -----------------------------------------------------------------------------
qdm_station <- function(obs, mod, dates,
                        cal_mask  = NULL,
                        by_month  = TRUE,
                        n_q       = 0L,     # 0 = adaptive
                        min_n_cal = 5L,
                        ...) {

  n <- length(obs)
  stopifnot(length(mod) == n, length(dates) == n)

  dates_d <- as.Date(dates)
  months  <- as.integer(format(dates_d, "%m"))

  # Auto-detect calibration period = overlap (both obs and mod finite)
  if (is.null(cal_mask))
    cal_mask <- is.finite(obs) & is.finite(mod)

  corrected <- rep(NA_real_, n)

  do_month <- function(m) {
    app_idx <- which(months == m)
    cal_idx <- which(months == m & cal_mask & is.finite(obs) & is.finite(mod))

    if (length(cal_idx) < min_n_cal) {
      corrected[app_idx] <<- mod[app_idx]
      return(invisible(NULL))
    }

    # Adaptive n_q
    n_q_eff <- if (n_q == 0L) floor(0.8 * length(cal_idx)) else n_q

    corrected[app_idx] <<- qdm_correct(
      obs_cal = obs[cal_idx],
      mod_cal = mod[cal_idx],
      mod_app = mod[app_idx],
      n_q     = n_q_eff,
      ...
    )
  }

  if (by_month) lapply(1:12L, do_month)
  else {
    cal_idx <- which(cal_mask & is.finite(obs) & is.finite(mod))
    n_q_eff <- if (n_q == 0L) floor(0.8 * length(cal_idx)) else n_q
    corrected <- qdm_correct(obs[cal_idx], mod[cal_idx], mod, n_q = n_q_eff, ...)
    corrected[!is.finite(mod)] <- NA_real_
  }

  corrected
}


# -----------------------------------------------------------------------------
# 3. LEAVE-ONE-YEAR-OUT CV (LOYO-CV)
# -----------------------------------------------------------------------------
# With only 10–20 years of obs, a single train/test split wastes data and
# produces unstable estimates. LOYO-CV withholds one year at a time (per month),
# fits QDM on the remaining years, predicts that year, cycles through all years.
#
# Returns: data.frame with columns
#   date, obs, mod_raw, mod_cor, month, year
#   (only rows within the obs-coverage period)
# -----------------------------------------------------------------------------
qdm_loyo_cv <- function(obs, mod, dates,
                        by_month  = TRUE,
                        min_n_cal = 4L,
                        ...) {

  n       <- length(obs)
  dates_d <- as.Date(dates)
  months  <- as.integer(format(dates_d, "%m"))
  years   <- as.integer(format(dates_d, "%Y"))

  # Only evaluate where both obs and mod are available
  valid   <- is.finite(obs) & is.finite(mod)
  obs_yrs <- unique(years[valid])

  mod_cor <- rep(NA_real_, n)

  for (yr in obs_yrs) {
    val_idx <- which(years == yr & valid)
    cal_idx_all <- which(years != yr & valid)   # all other valid obs years

    if (!by_month) {
      n_q_eff <- floor(0.8 * length(cal_idx_all))
      mod_cor[val_idx] <- qdm_correct(
        obs_cal = obs[cal_idx_all],
        mod_cal = mod[cal_idx_all],
        mod_app = mod[val_idx],
        n_q     = n_q_eff, ...
      )
    } else {
      for (m in unique(months[val_idx])) {
        v_m   <- val_idx[months[val_idx] == m]
        c_m   <- which(years != yr & valid & months == m)
        if (length(c_m) < min_n_cal) { mod_cor[v_m] <- mod[v_m]; next }
        n_q_eff <- floor(0.8 * length(c_m))
        mod_cor[v_m] <- qdm_correct(obs[c_m], mod[c_m], mod[v_m],
                                    n_q = n_q_eff, ...)
      }
    }
  }

  data.frame(
    date    = dates_d[valid],
    obs     = obs[valid],
    mod_raw = mod[valid],
    mod_cor = mod_cor[valid],
    month   = months[valid],
    year    = years[valid]
  )
}


# -----------------------------------------------------------------------------
# 4. EVALUATION METRICS
# -----------------------------------------------------------------------------
# Computes RMSE, MAE, PBIAS, R² for raw and corrected ERA5 vs. obs.
# Works on the output of qdm_loyo_cv or any paired data.frame.
#
# df:       data.frame with cols: obs, mod_raw, mod_cor
# by_month: also compute per calendar month
# -----------------------------------------------------------------------------
qdm_eval <- function(df, by_month = FALSE) {

  .metrics <- function(pred, obs) {
    ok  <- is.finite(pred) & is.finite(obs)
    p   <- pred[ok]; o <- obs[ok]
    err <- p - o
    c(n     = sum(ok),
      RMSE  = sqrt(mean(err^2)),
      MAE   = mean(abs(err)),
      PBIAS = 100 * sum(p - o) / sum(o),
      R2    = cor(p, o)^2)
  }

  global <- rbind(
    raw       = .metrics(df$mod_raw, df$obs),
    corrected = .metrics(df$mod_cor, df$obs)
  )

  if (!by_month) return(as.data.frame(global))

  monthly <- do.call(rbind, lapply(1:12, function(m) {
    sub <- df[df$month == m, ]
    rbind(
      data.frame(month = m, phase = "raw",       as.data.frame(t(.metrics(sub$mod_raw, sub$obs)))),
      data.frame(month = m, phase = "corrected", as.data.frame(t(.metrics(sub$mod_cor, sub$obs))))
    )
  }))

  list(global = as.data.frame(global), monthly = monthly)
}


# -----------------------------------------------------------------------------
# 5. VECTORIZED WRAPPERS
# -----------------------------------------------------------------------------

# --- 5a. Named list of stations -------------------------------------------
# station_list: named list of data.frames, each with cols: date, obs, mod
# Returns: named list of corrected ERA5 vectors (full 30yr length each)
qdm_apply <- function(station_list, ...) {
  lapply(station_list, function(s) {
    qdm_station(obs = s$obs, mod = s$mod, dates = s$date, ...)
  })
}

# --- 5b. [time × stations] matrices ----------------------------------------
# obs_mat / mod_mat: matrix [n_time × n_stations]; NAs where obs absent
# dates: Date vector length n_time (full ERA5 period)
# cal_mask: NULL (auto from obs_mat) or logical vector length n_time
#
# Returns: corrected matrix same dims as mod_mat
qdm_matrix <- function(obs_mat, mod_mat, dates, cal_mask = NULL, ...) {
  stopifnot(identical(dim(obs_mat), dim(mod_mat)),
            nrow(obs_mat) == length(dates))

  result <- vapply(
    seq_len(ncol(obs_mat)),
    FUN = function(j) {
      cm <- if (is.null(cal_mask)) NULL else cal_mask  # or per-column if matrix
      qdm_station(obs_mat[, j], mod_mat[, j], dates, cal_mask = cm, ...)
    },
    FUN.VALUE = numeric(nrow(obs_mat))
  )

  dimnames(result) <- dimnames(mod_mat)
  result
}

# --- 5c. LOYO-CV for all stations (returns list of CV data.frames) ----------
qdm_loyo_apply <- function(station_list, ...) {
  lapply(station_list, function(s) {
    qdm_loyo_cv(obs = s$obs, mod = s$mod, dates = s$date, ...)
  })
}


# -----------------------------------------------------------------------------
# 6. HELPERS
# -----------------------------------------------------------------------------

# Build station_list from wide obs/ERA5 data.frames (one col per station)
build_station_list <- function(obs_df, era5_df,
                               station_ids = NULL,
                               date_col    = "date") {
  ids <- if (is.null(station_ids))
    intersect(setdiff(names(obs_df), date_col), setdiff(names(era5_df), date_col))
  else station_ids

  setNames(
    lapply(ids, function(id) {
      data.frame(date = as.Date(obs_df[[date_col]]),
                 obs  = obs_df[[id]],
                 mod  = era5_df[[id]])
    }), ids
  )
}

# Summary table: one row per station with global CV metrics
qdm_cv_summary <- function(cv_list) {
  do.call(rbind, lapply(names(cv_list), function(id) {
    e <- qdm_eval(cv_list[[id]])
    data.frame(station = id, phase = rownames(e), e, row.names = NULL)
  }))
}


# =============================================================================
# USAGE EXAMPLE (not run)
# =============================================================================
if (FALSE) {

  library(lubridate)

  set.seed(7)
  # Full ERA5 period: 30 years monthly
  dates_era5 <- seq(as.Date("1990-01-01"), by = "month", length.out = 360L)

  # Simulate one station: obs available only 2000–2018 (19 years)
  obs_full <- rgamma(360L, shape = 3.5, scale = 18)
  mod_full <- obs_full * runif(360L, 0.65, 1.45) +
              sin(seq(0, 2*pi, length.out = 360L)) * 5 + 8  # systematic bias

  # Mask obs outside coverage window
  obs_masked <- ifelse(dates_era5 >= as.Date("2000-01-01") &
                       dates_era5 <= as.Date("2018-12-31"),
                       obs_full, NA_real_)

  # ── 1. Apply QDM (full 30yr correction) ───────────────────────────────────
  mod_corrected <- qdm_station(
    obs      = obs_masked,
    mod      = mod_full,
    dates    = dates_era5,
    # cal_mask = NULL → auto: uses obs_masked overlap
    type     = "ratio",
    min_val  = 0,
    zero_threshold = 0.1   # monthly mm floor
  )
  # mod_corrected has 360 values (full ERA5 period corrected)
  # cal used only 2000–2018; application covers 1990–2020

  # ── 2. LOYO-CV evaluation (only within obs period) ────────────────────────
  cv_df <- qdm_loyo_cv(
    obs    = obs_masked,
    mod    = mod_full,
    dates  = dates_era5,
    type   = "ratio",
    min_val = 0
  )

  # Global metrics
  qdm_eval(cv_df)

  # Per-month metrics
  qdm_eval(cv_df, by_month = TRUE)$monthly

  # ── 3. Multi-station matrix workflow ──────────────────────────────────────
  n_st  <- 360L
  n_t   <- 360L
  obs_m <- matrix(NA_real_, n_t, n_st)
  mod_m <- matrix(rgamma(n_t * n_st, 3, 20) + 8, n_t, n_st)

  # Each station has a random 10–20 year obs window within the ERA5 period
  for (j in seq_len(n_st)) {
    start_yr <- sample(1:20, 1)
    end_yr   <- start_yr + sample(9:19, 1)
    rows     <- which(year(dates_era5) >= 1990 + start_yr &
                      year(dates_era5) <= 1990 + end_yr)
    obs_m[rows, j] <- mod_m[rows, j] * runif(length(rows), 0.7, 1.3)
  }
  colnames(obs_m) <- colnames(mod_m) <- paste0("ST", seq_len(n_st))

  cor_m <- qdm_matrix(
    obs_mat = obs_m,
    mod_mat = mod_m,
    dates   = dates_era5,
    type    = "ratio",
    min_val = 0
  )
  # cor_m: [360 × 360] corrected ERA5, ready for further analysis

  # ── 4. LOYO-CV for all stations ───────────────────────────────────────────
  station_list <- build_station_list(
    obs_df  = data.frame(date = dates_era5, as.data.frame(obs_m)),
    era5_df = data.frame(date = dates_era5, as.data.frame(mod_m))
  )

  cv_list  <- qdm_loyo_apply(station_list, type = "ratio", min_val = 0)
  cv_table <- qdm_cv_summary(cv_list)

  # All stations: corrected RMSE vs raw RMSE
  cv_table[cv_table$phase == "corrected", c("station", "RMSE", "PBIAS", "R2")]
}
