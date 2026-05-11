# ============================================================
# SCRIPT 04 — ADD PARTICIPANT GENDER & RERUN GCA
# Nomina agentis VWP — rod x glas x prestiznost x pol
#
# WHAT THIS SCRIPT DOES:
#   1. Extracts participant gender from the questionnaire file
#   2. Excludes participants who did not declare gender (Response=3)
#   3. Merges gender into the clean gaze dataset
#   4. Reruns GCA with participant gender added as a factor
#      New interactions: rod x pol, glas x pol, prest x pol
#      plus time x these interactions
#   5. Saves updated model summary and plots
#
# INPUT:  data/processed/gaze_binned_CLEAN.csv
#         data/raw/gorilla/[questionnaire file]
#
# OUTPUT: data/processed/gaze_binned_GENDER.csv
#         data/processed/gca_model_gender_summary.txt
#         data/processed/plots/
# ============================================================


# ---- 0. PACKAGES -------------------------------------------
library(lme4)
library(lmerTest)
library(ggplot2)
library(dplyr)
library(here)


# ---- 1. LOAD QUESTIONNAIRE FILE ----------------------------
cat("Loading questionnaire data...\n")

# !! EDIT THIS LINE if your questionnaire file has a different name
questionnaire_raw <- read.csv(
  here("data", "raw", "gorilla",
       "data_exp_249742-v1_questionnaires.csv"),
  stringsAsFactors = FALSE,
  encoding = "UTF-8"
)

cat("  Total questionnaire rows:", nrow(questionnaire_raw), "\n")


# ---- 2. EXTRACT GENDER PER PARTICIPANT ---------------------
# Gender is stored in rows where:
#   Question == "Pol:"
#   Response.Type == "response"
#   Key == "value"
# Response values: 1 = female, 2 = male, 3 = did not declare

cat("Extracting gender responses...\n")

gender_raw <- questionnaire_raw %>%
  filter(
    trimws(Question)      == "Pol:",
    Response.Type         == "response",
    Key                   == "value"
  ) %>%
  rename(participant_id = Participant.Private.ID) %>%
  mutate(
    participant_id = as.character(participant_id),
    gender_code    = as.numeric(Response)
  ) %>%
  select(participant_id, gender_code)

cat("  Gender responses found:", nrow(gender_raw), "\n")

# Sanity check
cat("  Gender code distribution:\n")
print(table(gender_raw$gender_code, useNA = "always"))
cat("  (1 = female, 2 = male, 3 = did not declare)\n\n")


# ---- 3. EXCLUDE NON-DECLARERS & RECODE ---------------------
gender_clean <- gender_raw %>%
  filter(gender_code != 3) %>%
  mutate(
    pol = ifelse(gender_code == 1, "zenski", "muski")
  ) %>%
  select(participant_id, pol)

cat("  After excluding non-declarers:\n")
cat("    Participants with gender data:", nrow(gender_clean), "\n")
cat("    Excluded (code=3):",
    nrow(gender_raw) - nrow(gender_clean), "\n")
cat("  Gender distribution:\n")
print(table(gender_clean$pol))


# ---- 4. LOAD CLEAN GAZE DATA & MERGE -----------------------
cat("\nLoading clean gaze data...\n")

gaze <- read.csv(
  here("data", "processed", "gaze_binned_CLEAN.csv"),
  stringsAsFactors = FALSE
) %>%
  mutate(participant_id = as.character(participant_id))

cat("  Rows before merge:", nrow(gaze), "\n")
cat("  Participants before merge:",
    length(unique(gaze$participant_id)), "\n")

# Merge gender onto gaze data
# Participants with gender_code=3 are automatically excluded
# because they have no row in gender_clean
gaze_gender <- gaze %>%
  inner_join(gender_clean, by = "participant_id")

cat("  Rows after merge:", nrow(gaze_gender), "\n")
cat("  Participants after merge:",
    length(unique(gaze_gender$participant_id)), "\n")

n_excluded_gender <- length(unique(gaze$participant_id)) -
                     length(unique(gaze_gender$participant_id))
cat("  Participants excluded (did not declare gender):",
    n_excluded_gender, "\n\n")

# Export merged dataset
gender_path <- here("data", "processed", "gaze_binned_GENDER.csv")
write.csv(gaze_gender, gender_path, row.names = FALSE)
cat("Merged dataset saved to:", gender_path, "\n\n")


# ---- 5. EFFECT CODING --------------------------------------
data <- gaze_gender %>%
  mutate(
    # Existing IVs
    rod_c   = ifelse(rod         == "MNA",    -0.5,  0.5),
    glas_c  = ifelse(glas        == "muski",  -0.5,  0.5),
    prest_c = ifelse(prestiznost == "n",      -0.5,  0.5),
    # Participant gender
    # zenski (female) = -0.5 | muski (male) = +0.5
    pol_c   = ifelse(pol         == "zenski", -0.5,  0.5),
    participant_id = as.character(participant_id),
    item_id        = as.character(item_id)
  )

cat("Effect coding:\n")
cat("  rod:   MNA=-0.5  | ZNA=+0.5\n")
cat("  glas:  muski=-0.5 | zenski=+0.5\n")
cat("  prest: n=-0.5    | p=+0.5\n")
cat("  pol:   zenski=-0.5 | muski=+0.5\n\n")

# Verify
cat("pol_c distribution:\n")
print(table(data$pol, data$pol_c))


# ---- 6. ORTHOGONAL POLYNOMIAL TIME TERMS -------------------
time_vals <- sort(unique(data$time_bin))
time_poly <- poly(time_vals, degree = 2)

time_df <- data.frame(
  time_bin = time_vals,
  ot1      = time_poly[, 1],
  ot2      = time_poly[, 2]
)

data <- data %>%
  left_join(time_df, by = "time_bin")


# ---- 7. FIT UPDATED GCA MODEL ------------------------------
# This model adds participant gender (pol_c) as a new factor.
#
# We add:
#   Main effect of pol_c
#   Two-way interactions: pol_c x rod_c, pol_c x glas_c, pol_c x prest_c
#   Time interactions: ot1/ot2 x pol_c
#   Time x two-way interactions involving pol_c
#
# We keep the same random effects structure as the original model.

model_path <- here("data", "processed", "gca_model_gender.rds")

if (file.exists(model_path)) {
  cat("Loading previously fitted gender model...\n")
  model <- readRDS(model_path)
  cat("Model loaded.\n\n")

} else {
  cat("Fitting GCA model with participant gender...\n")
  cat("(This may take a few minutes)\n\n")

  model <- lmer(
    elogit ~

      # --- Time terms ---
      (ot1 + ot2) +

      # --- Main effects ---
      rod_c + glas_c + prest_c + pol_c +

      # --- Two-way interactions among stimulus IVs ---
      rod_c:glas_c +
      rod_c:prest_c +
      glas_c:prest_c +

      # --- Two-way interactions with participant gender ---
      rod_c:pol_c +
      glas_c:pol_c +
      prest_c:pol_c +

      # --- Time x main effects ---
      ot1:rod_c + ot2:rod_c +
      ot1:glas_c + ot2:glas_c +
      ot1:prest_c + ot2:prest_c +
      ot1:pol_c + ot2:pol_c +

      # --- Time x two-way interactions (stimulus IVs) ---
      ot1:rod_c:glas_c + ot2:rod_c:glas_c +
      ot1:rod_c:prest_c + ot2:rod_c:prest_c +
      ot1:glas_c:prest_c + ot2:glas_c:prest_c +

      # --- Time x two-way interactions with participant gender ---
      # These are the theoretically key new effects:
      # Does the rod effect on the looking curve differ
      # by participant gender?
      ot1:rod_c:pol_c + ot2:rod_c:pol_c +
      ot1:glas_c:pol_c + ot2:glas_c:pol_c +
      ot1:prest_c:pol_c + ot2:prest_c:pol_c +

      # --- Random effects ---
      (ot1 + ot2 | participant_id) +
      (1 | item_id),

    data    = data,
    weights = weight,
    REML    = TRUE,
    control = lmerControl(
      optimizer = "bobyqa",
      optCtrl   = list(maxfun = 2e5)
    )
  )

  saveRDS(model, model_path)
  cat("Model fitted and saved.\n\n")
}


# ---- 8. MODEL SUMMARY --------------------------------------
cat("=== MODEL SUMMARY ===\n\n")
model_summary <- summary(model)
print(model_summary)

# Save to file
summary_path <- here("data", "processed",
                     "gca_model_gender_summary.txt")
sink(summary_path)
cat("GCA Model Summary — with participant gender\n")
cat("Nomina agentis VWP — rod x glas x prestiznost x pol\n")
cat("DV: empirical logit (ZNA vs MNA)\n")
cat("Positive = more looks to female referent\n\n")
print(model_summary)
sink()
cat("\nModel summary saved to:", summary_path, "\n\n")


# ---- 9. CONVERGENCE CHECK ----------------------------------
cat("=== CONVERGENCE CHECK ===\n")
if (length(model@optinfo$conv$lme4) > 0) {
  cat("WARNING: convergence issues detected.\n")
  cat("Consider removing ot2 random slope:\n")
  cat("  Change (ot1 + ot2 | participant_id)\n")
  cat("  To     (ot1 | participant_id)\n\n")
} else {
  cat("Model converged successfully.\n\n")
}


# ---- 10. KEY EFFECTS TABLE ---------------------------------
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

cat("Time x condition interactions:\n")
print(as.data.frame(fe %>%
        filter(grepl("ot1|ot2", term)) %>%
        arrange(term)), row.names = FALSE)

cat("\nMain effects and static interactions:\n")
print(as.data.frame(fe %>%
        filter(!grepl("ot1|ot2", term),
               term != "(Intercept)")), row.names = FALSE)


# ---- 11. PLOTS ---------------------------------------------
dir.create(here("data", "processed", "plots"),
           showWarnings = FALSE)

# --- Plot 5: rod x pol (the key new question) ---
plot5_data <- data %>%
  group_by(time_bin, rod, pol) %>%
  summarise(
    mean_elogit = mean(elogit, na.rm = TRUE),
    se          = sd(elogit, na.rm = TRUE) / sqrt(n()),
    .groups     = "drop"
  ) %>%
  mutate(
    pol_label = ifelse(pol == "zenski",
                       "Female participants", "Male participants")
  )

p5 <- ggplot(plot5_data,
             aes(x = time_bin, y = mean_elogit,
                 colour = rod, fill = rod)) +
  geom_ribbon(aes(ymin = mean_elogit - se,
                  ymax = mean_elogit + se),
              alpha = 0.15, colour = NA) +
  geom_line(linewidth = 1) +
  geom_hline(yintercept = 0, linetype = "dashed",
             colour = "grey50") +
  facet_wrap(~ pol_label) +
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
    title    = "Noun gender effect by participant gender (pol)",
    subtitle = "Does grammatical gender prediction differ for male vs female participants?",
    x        = "Time from sentence onset (ms)",
    y        = "Empirical logit (ZNA vs MNA)",
    colour   = "Noun gender",
    fill     = "Noun gender"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    legend.position = "bottom",
    strip.text      = element_text(face = "bold")
  )

ggsave(here("data", "processed", "plots", "plot5_rod_x_pol.png"),
       p5, width = 10, height = 5)
cat("Plot 5 saved: plot5_rod_x_pol.png\n")


# --- Plot 6: Full design with participant gender ---
plot6_data <- data %>%
  group_by(time_bin, rod, pol, prestiznost) %>%
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

p6 <- ggplot(plot6_data,
             aes(x = time_bin, y = mean_elogit,
                 colour = rod, fill = rod)) +
  geom_ribbon(aes(ymin = mean_elogit - se,
                  ymax = mean_elogit + se),
              alpha = 0.12, colour = NA) +
  geom_line(linewidth = 0.9) +
  geom_hline(yintercept = 0, linetype = "dashed",
             colour = "grey50") +
  facet_grid(prest_label ~ pol_label) +
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
    title  = "Noun gender × prestige × participant gender",
    x      = "Time from sentence onset (ms)",
    y      = "Empirical logit (ZNA vs MNA)",
    colour = "Noun gender",
    fill   = "Noun gender"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    strip.text      = element_text(face = "bold")
  )

ggsave(here("data", "processed", "plots",
            "plot6_rod_x_prest_x_pol.png"),
       p6, width = 10, height = 7)
cat("Plot 6 saved: plot6_rod_x_prest_x_pol.png\n")


# ---- 12. FINAL SUMMARY -------------------------------------
cat("\n=== COMPLETE ===\n")
cat("Participants in final model:",
    length(unique(data$participant_id)), "\n")
cat("  Female participants:",
    sum(gender_clean$pol == "zenski" &
          gender_clean$participant_id %in%
          unique(data$participant_id)), "\n")
cat("  Male participants:",
    sum(gender_clean$pol == "muski" &
          gender_clean$participant_id %in%
          unique(data$participant_id)), "\n")
cat("\nFiles saved:\n")
cat("  data/processed/gaze_binned_GENDER.csv\n")
cat("  data/processed/gca_model_gender.rds\n")
cat("  data/processed/gca_model_gender_summary.txt\n")
cat("  data/processed/plots/plot5_rod_x_pol.png\n")
cat("  data/processed/plots/plot6_rod_x_prest_x_pol.png\n")
