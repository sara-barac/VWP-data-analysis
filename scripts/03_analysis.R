# ============================================================
# SCRIPT 03 — GROWTH CURVE ANALYSIS (GCA)
# Nomina agentis VWP — rod x glas x prestiznost
#
# WHAT THIS SCRIPT DOES:
#   1. Loads the clean preprocessed data
#   2. Effect-codes all three IVs (-.5 / +.5)
#   3. Creates orthogonal polynomial time terms (linear, quadratic)
#   4. Fits a linear mixed effects model (lme4)
#      DV: empirical logit of ZNA vs MNA looking
#      Fixed effects: rod, glas, prestiznost + all two-way
#                     interactions with each other and with time
#      Random effects: by-participant time course,
#                      by-item intercept
#   5. Prints model summary and interprets key effects
#   6. Visualises the time course by condition
#
# INPUT:  data/processed/gaze_binned_CLEAN.csv
# OUTPUT: data/processed/gca_model_summary.txt
#         data/processed/plots/
# ============================================================


# ---- 0. PACKAGES -------------------------------------------
# install.packages(c("lme4","lmerTest","ggplot2","dplyr","here"))

library(lme4)
library(lmerTest)   # adds p-values to lme4 output
library(ggplot2)
library(dplyr)
library(here)


# ---- 1. LOAD DATA ------------------------------------------
cat("Loading clean data...\n")

data <- read.csv(
  here("data", "processed", "gaze_binned_CLEAN.csv"),
  stringsAsFactors = FALSE
)

cat("  Rows:", nrow(data), "\n")
cat("  Participants:", length(unique(data$participant_id)), "\n")
cat("  Unique trials:",
    length(unique(paste(data$participant_id,
                        data$trial_number))), "\n")
cat("  Time bins:", length(unique(data$time_bin)),
    "(", min(data$time_bin), "to", max(data$time_bin), "ms )\n\n")


# ---- 2. EFFECT CODING --------------------------------------
# Effect coding: -.5 / +.5
# This makes the intercept = grand mean (not one reference level)
# and makes main effects interpretable in the presence of interactions
#
# Coding decisions:
#   rod:        MNA = -0.5  |  ZNA = +0.5
#   glas:       muski = -0.5  |  zenski = +0.5
#   prestiznost: n = -0.5  |  p = +0.5

data <- data %>%
  mutate(
    rod_c   = ifelse(rod         == "MNA",    -0.5,  0.5),
    glas_c  = ifelse(glas        == "muski",  -0.5,  0.5),
    prest_c = ifelse(prestiznost == "n",      -0.5,  0.5),

    # Ensure IDs are character for random effects
    participant_id = as.character(participant_id),
    item_id        = as.character(item_id)
  )

cat("Effect coding applied:\n")
cat("  rod:        MNA = -0.5 | ZNA = +0.5\n")
cat("  glas:       muski = -0.5 | zenski = +0.5\n")
cat("  prestiznost: n = -0.5 | p = +0.5\n\n")

# Verify coding
cat("rod_c distribution:\n")
print(table(data$rod, data$rod_c))
cat("\nglas_c distribution:\n")
print(table(data$glas, data$glas_c))
cat("\nprest_c distribution:\n")
print(table(data$prestiznost, data$prest_c))


# ---- 3. ORTHOGONAL POLYNOMIAL TIME TERMS -------------------
# We model the SHAPE of the looking curve over time using
# polynomial terms rather than raw milliseconds.
#
# ot1 = linear time term   (overall slope — does looking rise or fall?)
# ot2 = quadratic time term (curvature — does looking curve up or down?)
#
# Orthogonal polynomials are uncorrelated with each other,
# which makes model estimation more stable.
#
# We fit polynomials on the UNIQUE time bin values,
# then merge back to the full data.

time_vals  <- sort(unique(data$time_bin))
time_poly  <- poly(time_vals, degree = 2)

time_df <- data.frame(
  time_bin = time_vals,
  ot1      = time_poly[, 1],   # linear time
  ot2      = time_poly[, 2]    # quadratic time
)

data <- data %>%
  left_join(time_df, by = "time_bin")

cat("\n\nTime terms created:\n")
cat("  ot1 range:", round(min(data$ot1), 3),
    "to", round(max(data$ot1), 3), "\n")
cat("  ot2 range:", round(min(data$ot2), 3),
    "to", round(max(data$ot2), 3), "\n\n")


# ---- 4. FIT GCA MODEL --------------------------------------
# Model structure:
#
# FIXED EFFECTS:
#   Time terms (ot1, ot2) — capture the shape of the looking curve
#   Main effects of rod, glas, prestiznost
#   Two-way interactions among the three IVs
#   All IVs and their interactions × time (ot1 + ot2)
#   This tests whether conditions differ in their LOOKING CURVE SHAPE
#
# RANDOM EFFECTS:
#   (ot1 + ot2 | participant_id) — each participant has their own
#     baseline looking level and their own time course shape
#   (1 | item_id) — each occupation item has its own baseline
#     (we don't fit random slopes for items to keep model tractable)
#
# WEIGHTS:
#   The weight column (inverse variance) gives less influence to
#   time bins where very few looks were recorded


# If model has already been fitted, load it instead of refitting
model_path <- here("data", "processed", "gca_model.rds")

if (file.exists(model_path)) {
  cat("Loading previously fitted model...\n")
  model <- readRDS(model_path)
  cat("Model loaded.\n\n")
} else {
  cat("Fitting GCA model...\n")
  cat("(This may take a few minutes)\n\n")

model <- lmer(
  elogit ~

    # --- Time terms ---
    (ot1 + ot2) +

    # --- Main effects ---
    rod_c + glas_c + prest_c +

    # --- Two-way interactions among IVs ---
    rod_c : glas_c +
    rod_c : prest_c +
    glas_c : prest_c +

    # --- Time x main effect interactions ---
    # These test whether conditions differ in their looking curves
    ot1 : rod_c + ot2 : rod_c +
    ot1 : glas_c + ot2 : glas_c +
    ot1 : prest_c + ot2 : prest_c +

    # --- Time x two-way interactions ---
    # These test whether two-way interactions unfold differently over time
    ot1 : rod_c : glas_c + ot2 : rod_c : glas_c +
    ot1 : rod_c : prest_c + ot2 : rod_c : prest_c +
    ot1 : glas_c : prest_c + ot2 : glas_c : prest_c +

    # --- Random effects ---
    (ot1 + ot2 | participant_id) +   # by-participant time course
    (1 | item_id),                    # by-item intercept

  data    = data,
  weights = weight,
  REML    = TRUE,

  # Increase iterations in case of convergence warnings
  control = lmerControl(
    optimizer    = "bobyqa",
    optCtrl      = list(maxfun = 2e5)
  )
)

cat("Model fitted.\n\n")

# Save the fitted model so we never have to refit it
saveRDS(model, here("data", "processed", "gca_model.rds"))
cat("Model saved to data/processed/gca_model.rds\n\n")
}

# ---- 5. MODEL SUMMARY --------------------------------------
cat("=== MODEL SUMMARY ===\n\n")
model_summary <- summary(model)
print(model_summary)

# Save summary to file
summary_path <- here("data", "processed", "gca_model_summary.txt")
sink(summary_path)
cat("GCA Model Summary\n")
cat("Nomina agentis VWP — rod x glas x prestiznost\n")
cat("DV: empirical logit (ZNA vs MNA looking)\n")
cat("Positive values = more looks to female referent\n")
cat("Negative values = more looks to male referent\n\n")
print(model_summary)
sink()
cat("Model summary saved to:", summary_path, "\n\n")


# ---- 6. INTERPRET KEY EFFECTS ------------------------------
cat("=== KEY FIXED EFFECTS ===\n\n")

fe <- as.data.frame(coef(summary(model)))
fe$term <- rownames(fe)
colnames(fe)[colnames(fe) == "Pr(>|t|)"] <- "p_value"
colnames(fe)[colnames(fe) == "Std. Error"] <- "SE"
colnames(fe)[colnames(fe) == "t value"] <- "t_value"

fe <- fe %>%
  select(term, Estimate, SE, t_value, p_value) %>%
  mutate(
    sig = case_when(
      p_value < 0.001 ~ "***",
      p_value < 0.01  ~ "**",
      p_value < 0.05  ~ "*",
      p_value < 0.10  ~ ".",
      TRUE            ~ ""
    ),
    Estimate = round(Estimate, 4),
    SE       = round(SE, 4),
    t_value  = round(t_value, 3),
    p_value  = round(p_value, 5)
  )

cat("Time x condition interactions (the main findings):\n")
cat("Positive = more looks to ZNA (female referent)\n")
cat("Negative = more looks to MNA (male referent)\n\n")

key_effects <- fe %>%
  filter(grepl("ot1|ot2", term)) %>%
  arrange(term)

print(as.data.frame(key_effects), row.names = FALSE)
cat("\n")

cat("Main effects (overall bias regardless of time):\n")
main_effects <- fe %>%
  filter(!grepl("ot1|ot2", term), term != "(Intercept)")

print(as.data.frame(key_effects), row.names = FALSE)
cat("\n")

# ---- 7. CHECK FOR CONVERGENCE WARNINGS ---------------------
cat("\n=== CONVERGENCE CHECK ===\n")
if (length(model@optinfo$conv$lme4) > 0) {
  cat("WARNING: Model convergence issues detected.\n")
  cat("Consider simplifying the random effects structure.\n")
  cat("See 'Simplifying the model' section below.\n\n")
  cat("Suggested simplification — remove random slope for ot2:\n")
  cat("  Change: (ot1 + ot2 | participant_id)\n")
  cat("  To:     (ot1 | participant_id)\n")
} else {
  cat("Model converged successfully.\n\n")
}


# ---- 8. VISUALISATION --------------------------------------
# Create output folder for plots
dir.create(here("data", "processed", "plots"),
           showWarnings = FALSE)

# --- Plot 1: Time course by rod (main effect of noun gender) ---
plot1_data <- data %>%
  group_by(time_bin, rod) %>%
  summarise(
    mean_elogit = mean(elogit, na.rm = TRUE),
    se          = sd(elogit, na.rm = TRUE) / sqrt(n()),
    .groups     = "drop"
  )

p1 <- ggplot(plot1_data,
             aes(x = time_bin, y = mean_elogit,
                 colour = rod, fill = rod)) +
  geom_ribbon(aes(ymin = mean_elogit - se,
                  ymax = mean_elogit + se),
              alpha = 0.15, colour = NA) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed",
             colour = "grey50") +
  scale_colour_manual(
    values = c("MNA" = "#2166ac", "ZNA" = "#d6604d"),
    labels = c("MNA" = "Masculine noun (MNA)",
               "ZNA" = "Feminine noun (ZNA)")
  ) +
  scale_fill_manual(
    values = c("MNA" = "#2166ac", "ZNA" = "#d6604d"),
    labels = c("MNA" = "Masculine noun (MNA)",
               "ZNA" = "Feminine noun (ZNA)")
  ) +
  labs(
    title    = "Empirical logit by grammatical gender (rod)",
    subtitle = "Positive = more looks to female referent",
    x        = "Time from sentence onset (ms)",
    y        = "Empirical logit (ZNA vs MNA)",
    colour   = "Noun gender",
    fill     = "Noun gender"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")

ggsave(here("data", "processed", "plots", "plot1_rod.png"),
       p1, width = 8, height = 5)
cat("Plot 1 saved: plot1_rod.png\n")


# --- Plot 2: Time course by rod x glas ---
plot2_data <- data %>%
  group_by(time_bin, rod, glas) %>%
  summarise(
    mean_elogit = mean(elogit, na.rm = TRUE),
    se          = sd(elogit, na.rm = TRUE) / sqrt(n()),
    .groups     = "drop"
  ) %>%
  mutate(
    glas_label = ifelse(glas == "muski",
                        "Male voice", "Female voice")
  )

p2 <- ggplot(plot2_data,
             aes(x = time_bin, y = mean_elogit,
                 colour = rod, fill = rod,
                 linetype = glas_label)) +
  geom_ribbon(aes(ymin = mean_elogit - se,
                  ymax = mean_elogit + se),
              alpha = 0.10, colour = NA) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed",
             colour = "grey50") +
  scale_colour_manual(
    values = c("MNA" = "#2166ac", "ZNA" = "#d6604d")
  ) +
  scale_fill_manual(
    values = c("MNA" = "#2166ac", "ZNA" = "#d6604d")
  ) +
  labs(
    title    = "Empirical logit by noun gender x speaker voice",
    subtitle = "Positive = more looks to female referent",
    x        = "Time from sentence onset (ms)",
    y        = "Empirical logit (ZNA vs MNA)",
    colour   = "Noun gender",
    fill     = "Noun gender",
    linetype = "Speaker voice"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")

ggsave(here("data", "processed", "plots", "plot2_rod_x_glas.png"),
       p2, width = 9, height = 5)
cat("Plot 2 saved: plot2_rod_x_glas.png\n")


# --- Plot 3: Time course by rod x prestiznost ---
plot3_data <- data %>%
  group_by(time_bin, rod, prestiznost) %>%
  summarise(
    mean_elogit = mean(elogit, na.rm = TRUE),
    se          = sd(elogit, na.rm = TRUE) / sqrt(n()),
    .groups     = "drop"
  ) %>%
  mutate(
    prest_label = ifelse(prestiznost == "p",
                         "Prestigious", "Non-prestigious")
  )

p3 <- ggplot(plot3_data,
             aes(x = time_bin, y = mean_elogit,
                 colour = rod, fill = rod,
                 linetype = prest_label)) +
  geom_ribbon(aes(ymin = mean_elogit - se,
                  ymax = mean_elogit + se),
              alpha = 0.10, colour = NA) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed",
             colour = "grey50") +
  scale_colour_manual(
    values = c("MNA" = "#2166ac", "ZNA" = "#d6604d")
  ) +
  scale_fill_manual(
    values = c("MNA" = "#2166ac", "ZNA" = "#d6604d")
  ) +
  labs(
    title    = "Empirical logit by noun gender x prestige",
    subtitle = "Positive = more looks to female referent",
    x        = "Time from sentence onset (ms)",
    y        = "Empirical logit (ZNA vs MNA)",
    colour   = "Noun gender",
    fill     = "Noun gender",
    linetype = "Prestige"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")

ggsave(here("data", "processed", "plots", "plot3_rod_x_prest.png"),
       p3, width = 9, height = 5)
cat("Plot 3 saved: plot3_rod_x_prest.png\n")


# --- Plot 4: Full 2x2x2 faceted plot ---
plot4_data <- data %>%
  group_by(time_bin, rod, glas, prestiznost) %>%
  summarise(
    mean_elogit = mean(elogit, na.rm = TRUE),
    se          = sd(elogit, na.rm = TRUE) / sqrt(n()),
    .groups     = "drop"
  ) %>%
  mutate(
    glas_label  = ifelse(glas == "muski",
                         "Male voice", "Female voice"),
    prest_label = ifelse(prestiznost == "p",
                         "Prestigious", "Non-prestigious")
  )

p4 <- ggplot(plot4_data,
             aes(x = time_bin, y = mean_elogit,
                 colour = rod, fill = rod)) +
  geom_ribbon(aes(ymin = mean_elogit - se,
                  ymax = mean_elogit + se),
              alpha = 0.15, colour = NA) +
  geom_line(linewidth = 0.9) +
  geom_hline(yintercept = 0, linetype = "dashed",
             colour = "grey50") +
  facet_grid(prest_label ~ glas_label) +
  scale_colour_manual(
    values = c("MNA" = "#2166ac", "ZNA" = "#d6604d"),
    labels = c("MNA" = "Masculine noun",
               "ZNA" = "Feminine noun")
  ) +
  scale_fill_manual(
    values = c("MNA" = "#2166ac", "ZNA" = "#d6604d"),
    labels = c("MNA" = "Masculine noun",
               "ZNA" = "Feminine noun")
  ) +
  labs(
    title   = "Full 2×2×2 design: noun gender × voice × prestige",
    x       = "Time from sentence onset (ms)",
    y       = "Empirical logit (ZNA vs MNA)",
    colour  = "Noun gender",
    fill    = "Noun gender"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position  = "bottom",
    strip.text       = element_text(face = "bold")
  )

ggsave(here("data", "processed", "plots", "plot4_full_design.png"),
       p4, width = 10, height = 7)
cat("Plot 4 saved: plot4_full_design.png\n")


# ---- 9. FINAL MESSAGE --------------------------------------
cat("\n=== ANALYSIS COMPLETE ===\n")
cat("Files saved to data/processed/:\n")
cat("  gca_model_summary.txt  — full model output\n")
cat("  plots/plot1_rod.png\n")
cat("  plots/plot2_rod_x_glas.png\n")
cat("  plots/plot3_rod_x_prest.png\n")
cat("  plots/plot4_full_design.png\n\n")

cat("INTERPRETATION GUIDE:\n")
cat("  Intercept     = grand mean looking (should be near 0)\n")
cat("  ot1           = overall linear trend across sentence\n")
cat("  ot2           = overall quadratic curvature\n")
cat("  rod_c         = overall bias toward ZNA (if +) or MNA (if -)\n")
cat("  ot1:rod_c     = KEY EFFECT: does noun gender shift the\n")
cat("                  slope of the looking curve?\n")
cat("  ot2:rod_c     = does noun gender change the curvature?\n")
cat("  ot1:rod_c:glas_c = does the rod x time effect differ\n")
cat("                     by speaker voice?\n")
cat("  ot1:rod_c:prest_c = does the rod x time effect differ\n")
cat("                      by prestige?\n")
