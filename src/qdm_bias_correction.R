# =============================================================================
# Quantile Delta Mapping (QDM) — Monthly Climate Bias Correction
# Cannon et al. (2015), Clim. Dyn. doi:10.1007/s00382-015-2552-3
#
# Designed for ERA5 vs. observed station monthly time series.
# All functions are pure (no side effects), composable, and apply-friendly.
# =============================================================================


# -----------------------------------------------------------------------------
# 1. CORE QDM — single paired vector set
# -----------------------------------------------------------------------------
#
# Algorithm (multiplicative / ratio, for precipitation):
#   τ_t  = F_{mod,app}(x_t)                      [quantile of x_t in app period]
#   δ_t  = x_t / Q_{mod,cal}(τ_t)                [multiplicative delta vs. cal]
#   x*_t = Q_{obs,cal}(τ_t) · δ_t                [apply delta to obs quantile]
#
# For additive (temperature):  δ = x_t − Q_{mod,cal}(τ_t),  x* = Q_{obs,cal}(τ_t) + δ
#
# Arguments:
#   obs_cal   numeric  Observed values in calibration period
#   mod_cal   numeric  Model (ERA5) values in calibration period
#   mod_app   numeric  Model values to correct (may overlap or differ from cal)
#   type      "ratio" | "difference"
#   n_q       integer  Number of quantile nodes (interpolation grid)
#   min_val   numeric  Floor applied after correction (0 for precipitation)
#
# Returns: numeric vector, same length as mod_app, NAs preserved.
# -----------------------------------------------------------------------------
qdm_correct <- function(obs_cal, mod_cal, mod_app,
                        type    = "ratio",
                        n_q     = 100,
                        min_val = 0) {

  obs_c <- obs_cal[is.finite(obs_cal)]
  mod_c <- mod_cal[is.finite(mod_cal)]

  if (length(obs_c) < 4 || length(mod_c) < 4) {
    warning("qdm_correct: < 4 finite values in cal period; returning raw mod_app")
    return(mod_app)
  }

  probs  <- seq(0, 1, length.out = n_q + 2L)
  q_obs  <- quantile(obs_c,  probs, type = 8L, names = FALSE)
  q_modc <- quantile(mod_c,  probs, type = 8L, names = FALSE)

  # Application-period model quantiles (used to map x_t → τ_t)
  mod_a_finite <- mod_app[is.finite(mod_app)]
  if (length(mod_a_finite) < 2L) return(mod_app)
  q_moda <- quantile(mod_a_finite, probs, type = 8L, names = FALSE)

  # τ_t: empirical quantile of each mod_app value within the app distribution
  # rule = 2 → clamp extrapolation to boundary quantile (conservative)
  tau <- approx(q_moda, probs, xout = mod_app, method = "linear", rule = 2L)$y

  # Obs and mod_cal quantile estimates at τ_t
  q_obs_tau  <- approx(probs, q_obs,  xout = tau, method = "linear", rule = 2L)$y
  q_modc_tau <- approx(probs, q_modc, xout = tau, method = "linear", rule = 2L)$y

  corrected <- if (type == "ratio") {
    delta <- mod_app / pmax(q_modc_tau, .Machine$double.eps)
    pmax(q_obs_tau * delta, min_val)
  } else {
    q_obs_tau + (mod_app - q_modc_tau)
  }

  corrected[!is.finite(mod_app)] <- NA_real_
  corrected
}


# -----------------------------------------------------------------------------
# 2. STATION-LEVEL QDM — applies qdm_correct per calendar month
# -----------------------------------------------------------------------------
#
# Arguments:
#   obs       numeric   Observed time series (may contain NAs)
#   mod       numeric   ERA5 time series (same length)
#   dates     Date/character  Dates corresponding to obs/mod
#   cal_mask  logical   Calibration period selector (TRUE = use for fitting)
#                       NULL → entire series used for calibration
#   by_month  logical   Fit separate QDM per calendar month (recommended for
#                       monthly data with seasonal bias structure)
#   min_n_cal integer   Minimum cal samples per month; skip month if below
#   ...       passed to qdm_correct (type, n_q, min_val)
#
# Returns: numeric vector (corrected mod), same length as input.
# -----------------------------------------------------------------------------
qdm_station <- function(obs, mod, dates,
                        cal_mask  = NULL,
                        by_month  = TRUE,
                        min_n_cal = 5L,
                        ...) {

  n <- length(obs)
  stopifnot(length(mod) == n, length(dates) == n)

  if (is.null(cal_mask)) cal_mask <- rep(TRUE, n)

  dates_d <- as.Date(dates)
  months  <- as.integer(format(dates_d, "%m"))
  corrected <- rep(NA_real_, n)

  do_month <- function(m) {
    app_idx <- which(months == m)
    cal_idx <- which(months == m & cal_mask & is.finite(obs) & is.finite(mod))

    if (length(cal_idx) < min_n_cal) {
      # Fall back: return raw ERA5 for this month
      corrected[app_idx] <<- mod[app_idx]
      return(invisible(NULL))
    }

    corrected[app_idx] <<- qdm_correct(
      obs_cal = obs[cal_idx],
      mod_cal = mod[cal_idx],
      mod_app = mod[app_idx],
      ...
    )
  }

  if (by_month) {
    lapply(1:12, do_month)
  } else {
    cal_idx <- which(cal_mask & is.finite(obs) & is.finite(mod))
    corrected <- qdm_correct(
      obs_cal = obs[cal_idx],
      mod_cal = mod[cal_idx],
      mod_app = mod,
      ...
    )
    corrected[!is.finite(mod)] <- NA_real_
  }

  corrected
}


# -----------------------------------------------------------------------------
# 3. VECTORIZED WRAPPER — list of stations
# -----------------------------------------------------------------------------
#
# station_list: named list; each element is a data.frame with columns:
#   date  (Date or coercible)
#   obs   (observed)
#   mod   (ERA5)
#
# All extra arguments forwarded to qdm_station.
# Returns: named list of corrected ERA5 vectors.
#
# Example:
#   corrected <- qdm_apply(station_list, cal_mask_fn = function(d) d < as.Date("2010-01-01"))
# -----------------------------------------------------------------------------
qdm_apply <- function(station_list,
                      cal_mask_fn = NULL,   # optional function(dates) → logical
                      ...) {

  lapply(station_list, function(s) {
    cal_mask <- if (!is.null(cal_mask_fn)) cal_mask_fn(as.Date(s$date)) else NULL
    qdm_station(obs      = s$obs,
                mod      = s$mod,
                dates    = s$date,
                cal_mask = cal_mask,
                ...)
  })
}


# -----------------------------------------------------------------------------
# 4. MATRIX WRAPPER — [time × stations] matrices
# -----------------------------------------------------------------------------
#
# obs_mat, mod_mat: numeric matrices, rows = time steps, cols = stations
# dates: Date vector, length = nrow(obs_mat)
# cal_mask: logical vector (length = nrow) or NULL
#
# Returns: corrected matrix, same dims as mod_mat
# -----------------------------------------------------------------------------
qdm_matrix <- function(obs_mat, mod_mat, dates,
                       cal_mask = NULL,
                       ...) {
  stopifnot(identical(dim(obs_mat), dim(mod_mat)),
            nrow(obs_mat) == length(dates))

  result <- vapply(
    seq_len(ncol(obs_mat)),
    FUN = function(j) {
      qdm_station(obs      = obs_mat[, j],
                  mod      = mod_mat[, j],
                  dates    = dates,
                  cal_mask = cal_mask,
                  ...)
    },
    FUN.VALUE = numeric(nrow(obs_mat))
  )

  dimnames(result) <- dimnames(mod_mat)
  result
}


# -----------------------------------------------------------------------------
# 5. EVALUATION METRICS — leave-one-out / train-test split
# -----------------------------------------------------------------------------
#
# Computes RMSE, MAE, PBIAS, R² comparing corrected ERA5 vs. obs.
# val_mask: if NULL, uses the full series (in-sample); else out-of-sample.
# -----------------------------------------------------------------------------
qdm_eval <- function(obs, mod_raw, mod_cor, val_mask = NULL) {

  if (is.null(val_mask)) val_mask <- rep(TRUE, length(obs))

  ok  <- val_mask & is.finite(obs) & is.finite(mod_raw) & is.finite(mod_cor)
  o   <- obs[ok];  r <- mod_raw[ok];  c_ <- mod_cor[ok]

  metrics <- function(x, ref) {
    err   <- x - ref
    pbias <- 100 * sum(x - ref) / sum(ref)
    r2    <- cor(x, ref, use = "complete.obs")^2
    c(RMSE  = sqrt(mean(err^2)),
      MAE   = mean(abs(err)),
      PBIAS = pbias,
      R2    = r2)
  }

  rbind(raw       = metrics(r,  o),
        corrected = metrics(c_, o))
}


# -----------------------------------------------------------------------------
# 6. CONVENIENCE: build station_list from wide data.frames
# -----------------------------------------------------------------------------
#
# obs_df, era5_df: data.frames with a 'date' column + one column per station
#   (same column names, same row order)
# station_ids: character vector of station IDs to process (NULL = all)
#
# Returns list ready for qdm_apply().
# -----------------------------------------------------------------------------
build_station_list <- function(obs_df, era5_df,
                               station_ids = NULL,
                               date_col    = "date") {

  ids <- if (is.null(station_ids)) {
    intersect(setdiff(names(obs_df),  date_col),
              setdiff(names(era5_df), date_col))
  } else station_ids

  setNames(
    lapply(ids, function(id) {
      data.frame(date = as.Date(obs_df[[date_col]]),
                 obs  = obs_df[[id]],
                 mod  = era5_df[[id]])
    }),
    ids
  )
}


# =============================================================================
# USAGE EXAMPLE (not run)
# =============================================================================
if (FALSE) {

  # ── Minimal example ──────────────────────────────────────────────────────
  set.seed(42)
  n     <- 372L  # 31 years × 12 months
  dates <- seq(as.Date("1990-01-01"), by = "month", length.out = n)

  obs <- rgamma(n, shape = 3, scale = 20)          # synthetic observed precip
  mod <- obs * runif(n, 0.6, 1.4) + rnorm(n, 10)  # biased ERA5 analog

  # Train/test split: calibrate on 1990–2009, validate on 2010–2020
  cal_mask <- dates < as.Date("2010-01-01")
  val_mask <- !cal_mask

  mod_cor <- qdm_station(
    obs      = obs,
    mod      = mod,
    dates    = dates,
    cal_mask = cal_mask,
    by_month = TRUE,
    type     = "ratio",
    n_q      = 50L,
    min_val  = 0
  )

  qdm_eval(obs, mod, mod_cor, val_mask = val_mask)

  # ── Matrix / multi-station ───────────────────────────────────────────────
  n_stations <- 360L
  obs_mat    <- matrix(rgamma(n * n_stations, 3, 20), nrow = n)
  mod_mat    <- obs_mat * matrix(runif(n * n_stations, .7, 1.3), nrow = n) + 5

  cor_mat <- qdm_matrix(
    obs_mat  = obs_mat,
    mod_mat  = mod_mat,
    dates    = dates,
    cal_mask = cal_mask,
    type     = "ratio",
    n_q      = 50L
  )
  # cor_mat: same dims as mod_mat, columns processed independently

  # ── list workflow ────────────────────────────────────────────────────────
  station_list <- lapply(1:5, function(i) {
    data.frame(date = dates,
               obs  = rgamma(n, 3, 15),
               mod  = rgamma(n, 3, 20) + 8)
  })
  names(station_list) <- paste0("ST", 1:5)

  corrected_list <- qdm_apply(
    station_list,
    cal_mask_fn = function(d) d < as.Date("2010-01-01"),
    type        = "ratio",
    n_q         = 50L,
    min_val     = 0
  )

  # Evaluate all stations
  evals <- mapply(function(s, cor) {
    val_mask <- as.Date(s$date) >= as.Date("2010-01-01")
    qdm_eval(s$obs, s$mod, cor, val_mask = val_mask)
  }, station_list, corrected_list, SIMPLIFY = FALSE)

  # Bind into a single summary table
  do.call(rbind, lapply(names(evals), function(id) {
    e <- evals[[id]]
    data.frame(station = id, phase = rownames(e), e, row.names = NULL)
  }))
}
