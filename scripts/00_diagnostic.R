# ============================================================
# SCRIPT 00 — ZONE COORDINATE DIAGNOSTIC
# Run this independently to check zone coordinates
# before running the full preprocessing pipeline
# ============================================================

library(dplyr)
library(here)

# ---- FIND FILES --------------------------------------------
all_files <- list.files(
  path       = here("data", "raw", "gaze_csv"),
  pattern    = "\\.csv$",
  full.names = TRUE
)
cat("Total files found:", length(all_files), "\n")

# ---- CHECK FIRST 50 EXPERIMENTAL FILES ---------------------
n_diag     <- 50
zone_check <- vector("list", n_diag)
gaze_check <- vector("list", n_diag)
n_found    <- 0

for (i in seq_along(all_files)) {
  if (n_found >= n_diag) break

  df <- tryCatch(
    read.csv(all_files[[i]], stringsAsFactors = FALSE),
    error = function(e) NULL
  )
  if (is.null(df)) next
  if (!"eksperimentalni_deo" %in% unique(df$Display)) next

  n_found <- n_found + 1

  zones <- df %>%
    filter(Type == "zone",
           Zone.Name %in% c("TopLeft","TopRight",
                             "BottomLeft","BottomRight")) %>%
    select(Zone.Name, Zone.X, Zone.Y, Zone.W, Zone.H) %>%
    mutate(participant_id = as.character(
      unique(df$Participant.Private.ID)
    ))
  zone_check[[n_found]] <- zones

  preds <- df %>%
    filter(Type == "prediction") %>%
    select(gaze_x = Predicted.Gaze.X,
           gaze_y = Predicted.Gaze.Y) %>%
    filter(!is.na(gaze_x))
  gaze_check[[n_found]] <- preds
}

cat("Experimental files found and checked:", n_found, "\n\n")

# ---- ZONE SUMMARY ------------------------------------------
zone_df <- bind_rows(zone_check)

cat("Zone coordinate ranges:\n")
zone_summary <- zone_df %>%
  group_by(Zone.Name) %>%
  summarise(
    X_min      = min(Zone.X),
    X_max      = max(Zone.X),
    Y_min      = min(Zone.Y),
    Y_max      = max(Zone.Y),
    W_min      = min(Zone.W),
    W_max      = max(Zone.W),
    H_min      = min(Zone.H),
    H_max      = max(Zone.H),
    n_unique_X = n_distinct(Zone.X),
    .groups    = "drop"
  )
print(zone_summary)

# ---- GAZE SUMMARY ------------------------------------------
gaze_df <- bind_rows(gaze_check)

cat("\nGaze coordinate ranges:\n")
cat("Gaze X: min =", min(gaze_df$gaze_x, na.rm = TRUE),
    "| max =", max(gaze_df$gaze_x, na.rm = TRUE), "\n")
cat("Gaze Y: min =", min(gaze_df$gaze_y, na.rm = TRUE),
    "| max =", max(gaze_df$gaze_y, na.rm = TRUE), "\n")

# ---- KEY QUESTION ------------------------------------------
# If X_min == X_max for every zone (n_unique_X == 1),
# zone coordinates are FIXED — all participants same screen layout
# If X_min != X_max, coordinates VARY — screen resolution differs
cat("\nDiagnosis:\n")
if (all(zone_summary$n_unique_X == 1)) {
  cat("  Zone coordinates are IDENTICAL across all checked files.\n")
  cat("  The n_none issue is genuine webcam noise, not a coordinate problem.\n")
} else {
  cat("  Zone coordinates VARY across participants.\n")
  cat("  This explains the high n_none — gaze and zones are on different scales.\n")
  cat("  We need to use NORMALISED coordinates instead.\n")
} 