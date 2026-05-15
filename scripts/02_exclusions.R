# ============================================================
# SKRIPTA 2 — Isključivanje ispitanika i netačnih odgovora
# 
# Ova skripta:
#   1. ulitava screen 3 (ekran gde su ispitanici davali odgovore na kontrolna pitanja)
#   2. računa tačnost po ispitaniku
#   3. isključuje ispitanike sa manje od 90% tačnosti
#   4. isključuje pojedinačne trial-e na kojima su dati netačni odgovori
#   5. čuva prečišćen dataset
#
# INPUT:  data/processed/gaze_binned_FULL.csv
#         data/raw/gorilla/data_exp_249742-v1_tasks.csv
#
# AUTPUT: data/processed/gaze_binned_CLEAN.csv
#         data/processed/exclusion_report.csv
# ============================================================


# ---- 0. biblioteke -------------------------------------------
library(dplyr)
library(here)


# ---- 1. učitavanje podataka ------------------------------------------
cat("Loading preprocessed gaze data...\n")

gaze <- read.csv(
  here("data", "processed", "gaze_binned_FULL.csv"),
  stringsAsFactors = FALSE
)

cat("  Rows:", nrow(gaze), "\n")
cat("  Participants:", length(unique(gaze$participant_id)), "\n")
cat("  Unique participant x trial combinations:",
    length(unique(paste(gaze$participant_id,
                        gaze$trial_number))), "\n\n")

cat("Loading metadata...\n")

meta <- read.csv(
  here("data", "raw", "gorilla", "data_exp_249742-v1_tasks.csv"),
  stringsAsFactors = FALSE,
  encoding = "UTF-8"
)

cat("  Total metadata rows:", nrow(meta), "\n\n")


# ---- 2. EXTRACT SCREEN 3 RESPONSES -------------------------
# Screen 3 = the comprehension question screen
# Participant pressed 'da' or 'ne'
# Gorilla already scored this in the 'Correct' column:
#   1 = participant's response matched Spreadsheet: correct_anwser
#   0 = it did not

cat("Extracting comprehension question responses...\n")

# Detect the correct answer column name safely
# (handles encoding differences across machines)
col_correct <- grep("correct_anwser",
                    names(meta),
                    value       = TRUE,
                    ignore.case = TRUE)[1]

cat("  Correct answer column detected:", col_correct, "\n")

# Extract Screen 3 response rows from experimental trials only
responses <- meta %>%
  filter(
    Display       == "eksperimentalni_deo",
    Screen.Counter        == "3",
    Response.Type == "response"
  ) %>%
  rename(
    participant_id   = Participant.Private.ID,
    trial_number     = Trial.Number,
    participant_resp = Response,
    correct_answer   = !!col_correct
  ) %>%
  mutate(
    participant_id   = as.character(participant_id),
    participant_resp = tolower(trimws(participant_resp)),
    correct_answer   = tolower(trimws(correct_answer)),
    # Use Gorilla's own pre-computed scoring
    # Correct == 1 means the participant was right
    # Correct == 0 means the participant was wrong
    is_correct       = Correct == 1
  ) %>%
  select(participant_id, trial_number,
         participant_resp, correct_answer,
         is_correct)

cat("  Total comprehension responses found:", nrow(responses), "\n")
cat("  Overall accuracy rate:",
    round(100 * mean(responses$is_correct, na.rm = TRUE), 1), "%\n\n")

# Sanity checks
cat("  Unique participant responses (should be 'da' and 'ne'):\n")
print(table(responses$participant_resp, useNA = "always"))

cat("\n  Unique correct answers (should be 'da' and 'ne'):\n")
print(table(responses$correct_answer, useNA = "always"))

cat("\n  is_correct breakdown:\n")
print(table(responses$is_correct, useNA = "always"))


# ---- 3. COMPUTE PER-PARTICIPANT ACCURACY -------------------
cat("\nComputing per-participant accuracy...\n")

participant_accuracy <- responses %>%
  group_by(participant_id) %>%
  summarise(
    n_trials     = n(),
    n_correct    = sum(is_correct, na.rm = TRUE),
    n_incorrect  = sum(!is_correct, na.rm = TRUE),
    accuracy     = n_correct / n_trials,
    accuracy_pct = round(100 * accuracy, 1),
    .groups      = "drop"
  ) %>%
  arrange(accuracy)

cat("\n  Accuracy summary across all participants:\n")
print(summary(participant_accuracy$accuracy_pct))

cat("\n  Full per-participant accuracy table:\n")
print(participant_accuracy, n = Inf)


# ---- 4. APPLY EXCLUSION CRITERIA ---------------------------
ACCURACY_THRESHOLD <- 0.90   # 90% correct required

# Participants BELOW threshold -> excluded entirely
excluded_participants <- participant_accuracy %>%
  filter(accuracy < ACCURACY_THRESHOLD) %>%
  mutate(exclusion_reason = paste0(
    "Accuracy below 90% (", accuracy_pct, "%)"
  ))

# Participants AT or ABOVE threshold -> kept
kept_participants <- participant_accuracy %>%
  filter(accuracy >= ACCURACY_THRESHOLD)

cat("\n--- EXCLUSION SUMMARY ---\n")
cat("  Threshold: 90% accuracy on comprehension questions\n")
cat("  Total participants in gaze data:",
    length(unique(gaze$participant_id)), "\n")
cat("  Participants EXCLUDED (below 90%):",
    nrow(excluded_participants), "\n")
cat("  Participants KEPT:",
    nrow(kept_participants), "\n")

if (nrow(excluded_participants) > 0) {
  cat("\n  Excluded participants:\n")
  print(excluded_participants %>%
          select(participant_id, n_trials,
                 n_correct, accuracy_pct,
                 exclusion_reason))
}


# ---- 5. IDENTIFY INCORRECT TRIALS TO REMOVE ----------------
# For KEPT participants, find the specific trials they got wrong
# These trials are removed even though the participant stays in

incorrect_trials <- responses %>%
  filter(
    participant_id %in% kept_participants$participant_id,
    is_correct     == FALSE
  ) %>%
  select(participant_id, trial_number)

cat("\n  Incorrect trials to remove from kept participants:",
    nrow(incorrect_trials), "\n")

# Show how many incorrect trials each kept participant had
if (nrow(incorrect_trials) > 0) {
  incorrect_per_ppt <- incorrect_trials %>%
    count(participant_id, name = "n_incorrect_trials")
  cat("  Incorrect trials per participant:\n")
  print(incorrect_per_ppt)
}


# ---- 6. APPLY EXCLUSIONS TO GAZE DATA ----------------------
cat("\nApplying exclusions to gaze data...\n")

# Ensure participant_id is character type for safe joining
gaze <- gaze %>%
  mutate(participant_id = as.character(participant_id))

# Step 1: remove excluded participants entirely
gaze_clean <- gaze %>%
  filter(!participant_id %in% excluded_participants$participant_id)

cat("  After participant exclusion:\n")
cat("    Rows:", nrow(gaze_clean), "\n")
cat("    Participants:",
    length(unique(gaze_clean$participant_id)), "\n")

# Step 2: remove incorrect trials from kept participants
# anti_join() keeps only rows in gaze_clean that have
# NO match in incorrect_trials
# i.e. it removes the wrong-answer trials
gaze_clean <- gaze_clean %>%
  anti_join(incorrect_trials,
            by = c("participant_id", "trial_number"))

cat("\n  After incorrect trial exclusion:\n")
cat("    Rows:", nrow(gaze_clean), "\n")
cat("    Participants:",
    length(unique(gaze_clean$participant_id)), "\n")
cat("    Unique participant x trial combinations:",
    length(unique(paste(gaze_clean$participant_id,
                        gaze_clean$trial_number))), "\n")


# ---- 7. TRIAL LOSS SUMMARY ---------------------------------
trials_before <- gaze %>%
  filter(participant_id %in% kept_participants$participant_id) %>%
  distinct(participant_id, trial_number) %>%
  count(participant_id, name = "trials_before")

trials_after <- gaze_clean %>%
  distinct(participant_id, trial_number) %>%
  count(participant_id, name = "trials_after")

trial_loss <- trials_before %>%
  left_join(trials_after, by = "participant_id") %>%
  mutate(
    trials_after   = coalesce(trials_after, 0L),
    trials_removed = trials_before - trials_after
  )

cat("\n  Trials per participant before and after trial exclusion:\n")
print(trial_loss)


# ---- 8. EXPORT EXCLUSION REPORT ----------------------------
# A complete record of every decision — useful for your methods section

report <- participant_accuracy %>%
  mutate(
    excluded = participant_id %in% excluded_participants$participant_id,
    exclusion_reason = ifelse(
      excluded,
      paste0("Accuracy below 90% (", accuracy_pct, "%)"),
      "Kept"
    )
  ) %>%
  left_join(
    trial_loss %>% select(participant_id, trials_removed),
    by = "participant_id"
  ) %>%
  mutate(trials_removed = coalesce(trials_removed, 0L))

report_path <- here("data", "processed", "exclusion_report.csv")
write.csv(report, report_path, row.names = FALSE)
cat("\nExclusion report saved to:", report_path, "\n")


# ---- 9. EXPORT CLEAN GAZE DATA -----------------------------
clean_path <- here("data", "processed", "gaze_binned_CLEAN.csv")
write.csv(gaze_clean, clean_path, row.names = FALSE)
cat("Clean gaze data saved to:", clean_path, "\n")


# ---- 10. FINAL SUMMARY -------------------------------------
cat("\n=== EXCLUSION COMPLETE ===\n")
cat("  Original participants:  ",
    length(unique(gaze$participant_id)), "\n")
cat("  Excluded participants:  ",
    nrow(excluded_participants), "\n")
cat("  Remaining participants: ",
    length(unique(gaze_clean$participant_id)), "\n")
cat("  Incorrect trials removed from kept participants: ",
    nrow(incorrect_trials), "\n")
cat("  Final rows in clean dataset: ", nrow(gaze_clean), "\n")

cat("\n  --- Methods section wording ---\n")
cat(paste0(
  "  '",
  nrow(excluded_participants),
  " participant(s) were excluded for accuracy below 90% on the ",
  "comprehension task (chance = 50%). An additional ",
  nrow(incorrect_trials),
  " trial(s) were removed due to incorrect responses, leaving ",
  length(unique(gaze_clean$participant_id)),
  " participants and ",
  length(unique(paste(gaze_clean$participant_id,
                      gaze_clean$trial_number))),
  " valid trials for analysis.'\n"
))
