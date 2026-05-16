# ============================================================
# SCRIPT 03 — PARTICIPANT GENDER MERGE
# Nomina agentis VWP — rod x glas x prestiznost x pol
#
# WHAT THIS SCRIPT DOES:
#   1. Reads participant gender from the Gorilla questionnaire file
#   2. Excludes participants who did not declare gender (Response = 3)
#   3. Merges gender onto the clean gaze dataset
#   4. Saves the final analysis-ready dataset
#
# INPUT:  data/processed/gaze_binned_CLEAN.csv
#         data/raw/gorilla/data_exp_249742-v1_questionnaires.csv
#
# OUTPUT: data/processed/gaze_binned_GENDER.csv
# ============================================================


# ---- 0. PACKAGES -------------------------------------------
library(dplyr)
library(here)


# ---- 1. LOAD QUESTIONNAIRE FILE ----------------------------
cat("Loading questionnaire data...\n")

# !! EDIT THIS LINE if your questionnaire filename differs
questionnaire_raw <- read.csv(
  here("data", "raw", "gorilla",
       "data_exp_249742-v1_questionnaires.csv"),
  stringsAsFactors = FALSE,
  encoding = "UTF-8"
)

cat("  Total questionnaire rows:", nrow(questionnaire_raw), "\n")
cat("  Unique participants:",
    length(unique(questionnaire_raw$Participant.Private.ID)), "\n\n")


# ---- 2. EXTRACT GENDER PER PARTICIPANT ---------------------
# Gender is stored in rows where:
#   Question == "Pol:"
#   Response.Type == "response"
#   Key == "value"
#
# Response values:
#   1 = female (zenski)
#   2 = male   (muski)
#   3 = did not declare → excluded

cat("Extracting gender responses...\n")

gender_raw <- questionnaire_raw %>%
  filter(
    trimws(Question) == "Pol:",
    Response.Type    == "response",
    Key              == "value"
  ) %>%
  rename(participant_id = Participant.Private.ID) %>%
  mutate(
    participant_id = as.character(participant_id),
    gender_code    = as.numeric(Response)
  ) %>%
  select(participant_id, gender_code)

cat("  Gender responses found:", nrow(gender_raw), "\n\n")

# Sanity check — should show 1s, 2s, and possibly 3s
cat("  Gender code distribution:\n")
print(table(gender_raw$gender_code, useNA = "always"))
cat("  (1 = male/muski, 2 = female/zenski,",
    "3 = did not declare)\n\n")


# ---- 3. EXCLUDE NON-DECLARERS & RECODE ---------------------
gender_clean <- gender_raw %>%
  filter(gender_code != 3) %>%
  mutate(
    pol = case_when(
      gender_code == 1 ~ "muski",
      gender_code == 2 ~ "zenski"
    )
  ) %>%
  select(participant_id, pol)

n_excluded <- nrow(gender_raw) - nrow(gender_clean)

cat("  Participants excluded (did not declare gender):",
    n_excluded, "\n")
cat("  Participants remaining:", nrow(gender_clean), "\n")
cat("  Gender distribution after exclusion:\n")
print(table(gender_clean$pol))


# ---- 4. LOAD CLEAN GAZE DATA -------------------------------
cat("\nLoading clean gaze data...\n")

gaze <- read.csv(
  here("data", "processed", "gaze_binned_CLEAN.csv"),
  stringsAsFactors = FALSE
) %>%
  mutate(participant_id = as.character(participant_id))

cat("  Rows:", nrow(gaze), "\n")
cat("  Participants:", length(unique(gaze$participant_id)), "\n\n")


# ---- 5. MERGE GENDER ONTO GAZE DATA ------------------------
# inner_join keeps only participants who have a gender entry
# Participants with gender_code = 3 are automatically excluded
# because they have no row in gender_clean

gaze_gender <- gaze %>%
  inner_join(gender_clean, by = "participant_id")

n_dropped <- length(unique(gaze$participant_id)) -
             length(unique(gaze_gender$participant_id))

cat("Merge complete:\n")
cat("  Rows before merge:", nrow(gaze), "\n")
cat("  Rows after merge: ", nrow(gaze_gender), "\n")
cat("  Participants before merge:",
    length(unique(gaze$participant_id)), "\n")
cat("  Participants after merge: ",
    length(unique(gaze_gender$participant_id)), "\n")
cat("  Participants dropped (gender not declared):",
    n_dropped, "\n\n")

# Final gender breakdown
cat("Final sample:\n")
gender_summary <- gaze_gender %>%
  distinct(participant_id, pol) %>%
  count(pol, name = "n_participants")
print(gender_summary)


# ---- 6. EXPORT ---------------------------------------------
output_path <- here("data", "processed", "gaze_binned_GENDER.csv")
write.csv(gaze_gender, output_path, row.names = FALSE)

cat("\nFinal dataset saved to:", output_path, "\n")
cat("Rows:", nrow(gaze_gender), "\n")
cat("Participants:", length(unique(gaze_gender$participant_id)), "\n")
cat("Columns:", paste(names(gaze_gender), collapse = ", "), "\n")

cat("\n=== SCRIPT 03 COMPLETE ===\n")
cat("Ready for Script 04 — Analysis\n")

# Methods section wording
n_female <- sum(gender_summary$n_participants[
  gender_summary$pol == "zenski"])
n_male <- sum(gender_summary$n_participants[
  gender_summary$pol == "muski"])

cat("\n  --- Methods section wording ---\n")
cat(paste0(
  "  'An additional ", n_dropped,
  " participant(s) were excluded for not declaring their gender,",
  " leaving a final sample of ",
  length(unique(gaze_gender$participant_id)),
  " participants (", n_female, " female, ", n_male, " male).'\n"
))
