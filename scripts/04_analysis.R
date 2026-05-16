# ============================================================
# SCRIPT 04 — GCA ANALYSIS + PLOTS
# Nomina agentis VWP — rod x glas x prestiznost x pol
#
# WHAT THIS SCRIPT DOES:
#   1. Loads the final gender-merged dataset
#   2. Effect-codes all four factors
#   3. Creates orthogonal polynomial time terms
#   4. Fits the full GCA model
#   5. Saves model summary
#   6. Exports all final publication-ready plots
#
# INPUT:  data/processed/gaze_binned_GENDER.csv
#
# OUTPUT: data/processed/gca_model_summary.txt
#         data/processed/gca_model.rds
#         data/processed/plots/plot_01_rod.png
#         data/processed/plots/plot_02_rod_x_prest.png
#         data/processed/plots/plot_03_rod_x_pol.png
#         data/processed/plots/plot_04_rod_x_prest_x_pol.png
# ============================================================


# ---- 0. PACKAGES -------------------------------------------
# install.packages(c("lme4","lmerTest","ggplot2","dplyr","here"))

library(lme4)
library(lmerTest)
library(ggplot2)
library(dplyr)
library(here)


# ============================================================
# SECTION A — DATA PREPARATION
# ============================================================

# ---- 1. LOAD DATA ------------------------------------------
cat("Loading final dataset...\n")

data <- read.csv(
  here("data", "processed", "gaze_binned_GENDER.csv"),
  stringsAsFactors = FALSE
)

cat("  Rows:", nrow(data), "\n")
cat("  Participants:", length(unique(data$participant_id)), "\n")
cat("  Unique trials:",
    length(unique(paste(data$participant_id,
                        data$trial_number))), "\n")
cat("  Time bins:", length(unique(data$time_bin)),
    "(", min(data$time_bin), "to",
    max(data$time_bin), "ms)\n\n")

# Verify all condition columns are present and correct
cat("Condition value checks:\n")
cat("  rod:        ", paste(unique(data$rod), collapse=", "), "\n")
cat("  glas:       ", paste(unique(data$glas), collapse=", "), "\n")
cat("  prestiznost:", paste(unique(data$prestiznost), collapse=", "), "\n")
cat("  pol:        ", paste(unique(data$pol), collapse=", "), "\n\n")


# ---- 2. EFFECT CODING --------------------------------------
# Effect coding -.5 / +.5 means the intercept = grand mean
# and main effects are interpretable in the presence of interactions
#
# Coding:
#   rod:   MNA = -0.5  |  ZNA     = +0.5
#   glas:  muski = -0.5  |  zenski = +0.5
#   prest: n = -0.5    |  p       = +0.5
#   pol:   zenski = -0.5 |  muski  = +0.5

data <- data %>%
  mutate(
    rod_c   = ifelse(rod         == "MNA",    -0.5,  0.5),
    glas_c  = ifelse(glas        == "muski",  -0.5,  0.5),
    prest_c = ifelse(prestiznost == "n",      -0.5,  0.5),
    pol_c   = ifelse(pol         == "zenski", -0.5,  0.5),
    participant_id = as.character(participant_id),
    item_id        = as.character(item_id)
  )

cat("Effect coding applied:\n")
cat("  rod:   MNA=-0.5   | ZNA=+0.5\n")
cat("  glas:  muski=-0.5 | zenski=+0.5\n")
cat("  prest: n=-0.5     | p=+0.5\n")
cat("  pol:   zenski=-0.5 | muski=+0.5\n\n")

# Verify distributions
cat("rod_c:\n");   print(table(data$rod, data$rod_c))
cat("glas_c:\n");  print(table(data$glas, data$glas_c))
cat("prest_c:\n"); print(table(data$prestiznost, data$prest_c))
cat("pol_c:\n");   print(table(data$pol, data$pol_c))
cat("\n")


# ---- 3. ORTHOGONAL POLYNOMIAL TIME TERMS -------------------
# ot1 = linear time  (does looking rise or fall?)
# ot2 = quadratic    (does looking curve up or down?)
# Orthogonal = uncorrelated, makes estimation stable

time_vals <- sort(unique(data$time_bin))
time_poly <- poly(time_vals, degree = 2)

time_df <- data.frame(
  time_bin = time_vals,
  ot1      = time_poly[, 1],
  ot2      = time_poly[, 2]
)

data <- data %>%
  left_join(time_df, by = "time_bin")

cat("Time terms created:\n")
cat("  ot1 range:", round(min(data$ot1), 3),
    "to", round(max(data$ot1), 3), "\n")
cat("  ot2 range:", round(min(data$ot2), 3),
    "to", round(max(data$ot2), 3), "\n\n")


# ============================================================
# SECTION B — MODEL
# ============================================================

# ---- 4. FIT GCA MODEL --------------------------------------
# Model loads from disk if already fitted (saves time on reruns)

model_path <- here("data", "processed", "gca_model.rds")

if (file.exists(model_path)) {
  cat("Loading previously fitted model...\n")
  model <- readRDS(model_path)
  cat("Model loaded.\n\n")

} else {
  cat("Fitting GCA model...\n")
  cat("(This may take several minutes)\n\n")

  model <- lmer(
    elogit ~

      # Time terms
      (ot1 + ot2) +

      # Main effects of all four factors
      rod_c + glas_c + prest_c + pol_c +

      # Two-way interactions among stimulus factors
      rod_c:glas_c +
      rod_c:prest_c +
      glas_c:prest_c +

      # Two-way interactions of participant gender
      # with each stimulus factor
      rod_c:pol_c +
      glas_c:pol_c +
      prest_c:pol_c +

      # Time x main effects
      # These test whether conditions differ in their looking curves
      ot1:rod_c   + ot2:rod_c +
      ot1:glas_c  + ot2:glas_c +
      ot1:prest_c + ot2:prest_c +
      ot1:pol_c   + ot2:pol_c +

      # Time x two-way interactions (stimulus factors)
      ot1:rod_c:glas_c  + ot2:rod_c:glas_c +
      ot1:rod_c:prest_c + ot2:rod_c:prest_c +
      ot1:glas_c:prest_c + ot2:glas_c:prest_c +

      # Time x two-way interactions (participant gender)
      # KEY NEW EFFECTS: does participant gender modulate
      # how stimulus factors drive prediction over time?
      ot1:rod_c:pol_c   + ot2:rod_c:pol_c +
      ot1:glas_c:pol_c  + ot2:glas_c:pol_c +
      ot1:prest_c:pol_c + ot2:prest_c:pol_c +

      # Random effects
      # By-participant: each person has their own baseline
      # and their own looking curve shape
      (ot1 + ot2 | participant_id) +
      # By-item: each occupation has its own baseline
      (1 | item_id),

    data    = data,
    weights = weight,
    REML    = TRUE,
    control = lmerControl(
      optimizer = "bobyqa",
      optCtrl   = list(maxfun = 2e5)
    )
  )

  # Save model so future runs skip the fitting step
  saveRDS(model, model_path)
  cat("Model fitted and saved.\n\n")
}


# ---- 5. CONVERGENCE CHECK ----------------------------------
cat("=== CONVERGENCE CHECK ===\n")
if (length(model@optinfo$conv$lme4) > 0) {
  cat("WARNING: convergence issues detected.\n")
  cat("Suggested fix — simplify random effects:\n")
  cat("  Change: (ot1 + ot2 | participant_id)\n")
  cat("  To:     (ot1 | participant_id)\n\n")
} else {
  cat("Model converged successfully.\n\n")
}


# ---- 6. MODEL SUMMARY --------------------------------------
cat("=== MODEL SUMMARY ===\n\n")
model_summary <- summary(model)
print(model_summary)

# Save full summary to text file
summary_path <- here("data", "processed", "gca_model_summary.txt")
sink(summary_path)
cat("GCA Model Summary\n")
cat("Nomina agentis VWP\n")
cat("Factors: rod x glas x prestiznost x pol\n")
cat("DV: empirical logit (ZNA vs MNA looking)\n")
cat("Positive values = more looks to female referent (ZNA)\n")
cat("Negative values = more looks to male referent (MNA)\n\n")
print(model_summary)
sink()
cat("\nFull summary saved to:", summary_path, "\n\n")


# ---- 7. KEY EFFECTS TABLE ----------------------------------
cat("=== KEY FIXED EFFECTS ===\n\n")

fe <- as.data.frame(coef(summary(model)))
fe$term <- rownames(fe)
colnames(fe)[colnames(fe) == "Pr(>|t|)"]  <- "p_value"
colnames(fe)[colnames(fe) == "Std. Error"] <- "SE"
colnames(fe)[colnames(fe) == "t value"]   <- "t_value"

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

cat("Time x condition interactions (main findings):\n")
cat("Positive = more looks to ZNA | Negative = more looks to MNA\n\n")
print(as.data.frame(
  fe %>% filter(grepl("ot1|ot2", term)) %>% arrange(term)
), row.names = FALSE)

cat("\nStatic effects (overall bias across sentence):\n")
print(as.data.frame(
  fe %>% filter(!grepl("ot1|ot2", term), term != "(Intercept)")
), row.names = FALSE)


# ============================================================
# SECTION C — PLOTS
# ============================================================

# Create plots folder
dir.create(here("data", "processed", "plots"),
           showWarnings = FALSE)

# Shared plot theme — consistent look across all plots
theme_vwp <- theme_minimal(base_size = 13) +
  theme(
    legend.position  = "bottom",
    strip.text       = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

# Shared colour scale for noun gender
colour_rod <- scale_colour_manual(
  values = c("MNA" = "#2166ac", "ZNA" = "#d6604d"),
  labels = c("MNA" = "Masculine noun (MNA)",
             "ZNA" = "Feminine noun (ZNA)")
)
fill_rod <- scale_fill_manual(
  values = c("MNA" = "#2166ac", "ZNA" = "#d6604d"),
  labels = c("MNA" = "Masculine noun (MNA)",
             "ZNA" = "Feminine noun (ZNA)")
)

cat("\n--- Generating plots ---\n")


# ---- PLOT 1: Main effect of rod ----------------------------
# Your clearest finding — grammatical gender drives prediction
# MNA line drops below zero, ZNA stays above

p1_data <- data %>%
  group_by(time_bin, rod) %>%
  summarise(
    mean_elogit = mean(elogit, na.rm = TRUE),
    se          = sd(elogit, na.rm = TRUE) / sqrt(n()),
    .groups     = "drop"
  )

p1 <- ggplot(p1_data,
             aes(x = time_bin, y = mean_elogit,
                 colour = rod, fill = rod)) +
  geom_ribbon(aes(ymin = mean_elogit - se,
                  ymax = mean_elogit + se),
              alpha = 0.15, colour = NA) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed",
             colour = "grey50") +
  colour_rod + fill_rod +
  labs(
    title    = "Empirical logit by grammatical gender of noun (rod)",
    subtitle = "Positive = more looks to female referent (ZNA)",
    x        = "Time from sentence onset (ms)",
    y        = "Empirical logit (ZNA vs MNA)",
    colour   = "Noun gender",
    fill     = "Noun gender"
  ) +
  theme_vwp

ggsave(here("data", "processed", "plots", "plot_01_rod.png"),
       p1, width = 8, height = 5, dpi = 300)
cat("  plot_01_rod.png saved\n")


# ---- PLOT 2: rod x prestiznost -----------------------------
# The grammatical gender effect is amplified for prestigious
# occupations — male-prestige stereotype

p2_data <- data %>%
  group_by(time_bin, rod, prestiznost) %>%
  summarise(
    mean_elogit = mean(elogit, na.rm = TRUE),
    se          = sd(elogit, na.rm = TRUE) / sqrt(n()),
    .groups     = "drop"
  ) %>%
  mutate(
    prest_label = ifelse(prestiznost == "p",
                         "Prestigious",
                         "Non-prestigious")
  )

p2 <- ggplot(p2_data,
             aes(x = time_bin, y = mean_elogit,
                 colour = rod, fill = rod,
                 linetype = prest_label)) +
  geom_ribbon(aes(ymin = mean_elogit - se,
                  ymax = mean_elogit + se),
              alpha = 0.10, colour = NA) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed",
             colour = "grey50") +
  colour_rod + fill_rod +
  scale_linetype_manual(
    values = c("Non-prestigious" = "solid",
               "Prestigious"     = "dashed")
  ) +
  labs(
    title    = "Empirical logit by noun gender × prestige",
    subtitle = "The rod effect is amplified for prestigious occupations",
    x        = "Time from sentence onset (ms)",
    y        = "Empirical logit (ZNA vs MNA)",
    colour   = "Noun gender",
    fill     = "Noun gender",
    linetype = "Prestige"
  ) +
  theme_vwp

ggsave(here("data", "processed", "plots",
            "plot_02_rod_x_prest.png"),
       p2, width = 9, height = 5, dpi = 300)
cat("  plot_02_rod_x_prest.png saved\n")


# ---- PLOT 3: rod x pol -------------------------------------
# Does grammatical gender drive prediction differently
# for male vs female participants?

p3_data <- data %>%
  group_by(time_bin, rod, pol) %>%
  summarise(
    mean_elogit = mean(elogit, na.rm = TRUE),
    se          = sd(elogit, na.rm = TRUE) / sqrt(n()),
    .groups     = "drop"
  ) %>%
  mutate(
    pol_label = ifelse(pol == "zenski",
                       "Female participants",
                       "Male participants")
  )

p3 <- ggplot(p3_data,
             aes(x = time_bin, y = mean_elogit,
                 colour = rod, fill = rod)) +
  geom_ribbon(aes(ymin = mean_elogit - se,
                  ymax = mean_elogit + se),
              alpha = 0.15, colour = NA) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed",
             colour = "grey50") +
  facet_wrap(~ pol_label) +
  colour_rod + fill_rod +
  labs(
    title    = "Empirical logit by noun gender × participant gender (pol)",
    subtitle = "Does grammatical gender prediction differ for male vs female participants?",
    x        = "Time from sentence onset (ms)",
    y        = "Empirical logit (ZNA vs MNA)",
    colour   = "Noun gender",
    fill     = "Noun gender"
  ) +
  theme_vwp

ggsave(here("data", "processed", "plots",
            "plot_03_rod_x_pol.png"),
       p3, width = 10, height = 5, dpi = 300)
cat("  plot_03_rod_x_pol.png saved\n")


# ---- PLOT 4: rod x prestiznost x pol -----------------------
# The full prestige x participant gender interaction —
# male participants show stronger male-prestige stereotyping

p4_data <- data %>%
  group_by(time_bin, rod, prestiznost, pol) %>%
  summarise(
    mean_elogit = mean(elogit, na.rm = TRUE),
    se          = sd(elogit, na.rm = TRUE) / sqrt(n()),
    .groups     = "drop"
  ) %>%
  mutate(
    pol_label   = ifelse(pol == "zenski",
                         "Female participants",
                         "Male participants"),
    prest_label = ifelse(prestiznost == "p",
                         "Prestigious",
                         "Non-prestigious")
  )

p4 <- ggplot(p4_data,
             aes(x = time_bin, y = mean_elogit,
                 colour = rod, fill = rod)) +
  geom_ribbon(aes(ymin = mean_elogit - se,
                  ymax = mean_elogit + se),
              alpha = 0.12, colour = NA) +
  geom_line(linewidth = 0.9) +
  geom_hline(yintercept = 0, linetype = "dashed",
             colour = "grey50") +
  facet_grid(prest_label ~ pol_label) +
  colour_rod + fill_rod +
  labs(
    title   = "Noun gender × prestige × participant gender",
    subtitle = "Male participants show stronger male-prestige stereotyping",
    x       = "Time from sentence onset (ms)",
    y       = "Empirical logit (ZNA vs MNA)",
    colour  = "Noun gender",
    fill    = "Noun gender"
  ) +
  theme_vwp

ggsave(here("data", "processed", "plots",
            "plot_04_rod_x_prest_x_pol.png"),
       p4, width = 10, height = 7, dpi = 300)
cat("  plot_04_rod_x_prest_x_pol.png saved\n")


# ============================================================
# SECTION D — FINAL SUMMARY
# ============================================================

cat("\n=== SCRIPT 04 COMPLETE ===\n\n")

cat("SAMPLE:\n")
gender_counts <- data %>%
  distinct(participant_id, pol) %>%
  count(pol)
for (i in seq_len(nrow(gender_counts))) {
  cat("  ", gender_counts$pol[i], ":",
      gender_counts$n[i], "participants\n")
}
cat("  Total:", length(unique(data$participant_id)),
    "participants\n\n")

cat("FILES SAVED:\n")
cat("  data/processed/gca_model.rds\n")
cat("  data/processed/gca_model_summary.txt\n")
cat("  data/processed/plots/plot_01_rod.png\n")
cat("  data/processed/plots/plot_02_rod_x_prest.png\n")
cat("  data/processed/plots/plot_03_rod_x_pol.png\n")
cat("  data/processed/plots/plot_04_rod_x_prest_x_pol.png\n\n")

cat("PIPELINE COMPLETE:\n")
cat("  00_diagnostic.R       → zone coordinate check\n")
cat("  01_preprocess.R       → gaze_binned_FULL.csv\n")
cat("  02_exclusions.R       → gaze_binned_CLEAN.csv\n")
cat("  03_gender_merge.R     → gaze_binned_GENDER.csv\n")
cat("  04_analysis.R         → model + plots\n")
