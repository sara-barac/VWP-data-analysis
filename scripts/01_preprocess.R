# ============================================================
# SKRIPTA 1:
#
# 1. učitava sve .csv-ove iz foldera data/raw/gaze_csv/
# 2. učitava metapodatke iz odgovarajućeg fajla iz foldera data/raw/gorilla/
# 
# AUTPUT: data/processed/gaze_binned_TEST.csv
# ============================================================

#oslobadjanje memorije zarad bržeg izvršenja skripte
gc()
options(expressions = 5e5)

# ---- 0. BIBLIOTEKE -------------------------------------------
# install.packages(c("readxl","dplyr","purrr","stringr","zoo","here"))

library(readxl)
library(dplyr)
library(purrr)
library(stringr)
library(zoo)
library(here)


# ---- 1. LISTA STIMULUSNIH IMENICA -------------------------------------
# kategorizacija svih imenica u odgovarajuću kategoriju (predstavljene su četiri: muška/ženska nomina agentis,
# predmet sadržan u rečenici i distraktor predmet)

mna_list <- c(
  "lekar.png", "pekar.png", "konobar.png", "kasir.png",
  "slikar.png", "postar.png", "bibliotekar.png", "hemicar.png",
  "frizer.png", "krojac.png", "apotekarr.png", "novinar.png",
  "zubar.png", "advokat.png"
)

zna_list <- c(
  "lekarka.png", "pekarka.png", "konobarica.png", "kasirka.png",
  "slikarka.png", "postarka.png", "bibliotekarka.png", "hemicarka.png",
  "frizerka.png", "krojacica.png", "apotekarrka.png", "novinarka.png",
  "zubarka.png", "advokatica.png"
)

predmet_list <- c(
  "metalofon.png", "punjac.png", "poklon.png", "cekic.png",
  "telefon.png", "radio.png", "akvarijum.png", "papir.png",
  "novcanik.png", "album.png", "hleb.png", "rostilj.png",
  "svetionik.png", "trosed.png"
)

dist_list <- c(
  "lak za nokte.png", "peskir.png", "kamera.png", "kosilica.png",
  "lopta.png", "viljuskar.png", "slusalice.png", "racunar.png",
  "patike.png", "skije.png", "flasa.png", "klavir.png",
  "avion.png", "lula.png"
)

classify_image <- function(img) {
  img <- tolower(trimws(as.character(img)))
  if (img %in% mna_list)     return("MNA")
  if (img %in% zna_list)     return("ZNA")
  if (img %in% predmet_list) return("predmet")
  if (img %in% dist_list)    return("dist")
  return(NA_character_)
}


# ---- 2. UČITAVANJE I FILTRIRANJE METAPODATAKA -----------------------------
cat("Loading metadata...\n")


metadata_raw <- read.csv(
  here("data", "raw", "gorilla", "data_exp_249742-v1_tasks.csv"), 
  stringsAsFactors = FALSE,
  encoding = "UTF-8"
)

cat("  Total rows in metadata:", nrow(metadata_raw), "\n")
cat("  Columns with 'zanimanje':",
    paste(grep("zanimanje", names(metadata_raw), value = TRUE),
          collapse = ", "), "\n")
cat("  Columns with 'presti':",
    paste(grep("presti", names(metadata_raw),
               value = TRUE, ignore.case = TRUE),
          collapse = ", "), "\n\n")

# 1: Identifikovanje imena kolona (regex kao sigurnosna mera)

col_zan_m   <- grep("zanimanje\\.m",  names(metadata_raw),
                    value = TRUE)[1]
col_zan_z   <- grep("zanimanje\\.",   names(metadata_raw),
                    value = TRUE)[
                    !grepl("zanimanje\\.m",
                           grep("zanimanje\\.", names(metadata_raw),
                                value = TRUE))][1]
col_predmet <- grep("\\.predmet",     names(metadata_raw),
                    value = TRUE)[1]
col_dist    <- grep("\\.dist",        names(metadata_raw),
                    value = TRUE)[1]
col_rod     <- grep("\\.rod",         names(metadata_raw),
                    value = TRUE)[1]
col_glas    <- grep("\\.glas",        names(metadata_raw),
                    value = TRUE)[1]
col_prest   <- grep("presti",         names(metadata_raw),
                    value = TRUE, ignore.case = TRUE)[1]
col_redni   <- grep("redni",          names(metadata_raw),
                    value = TRUE)[1]

cat("Column mapping resolved:\n")
cat("  zanimanje m  ->", col_zan_m,   "\n")
cat("  zanimanje z  ->", col_zan_z,   "\n")
cat("  predmet      ->", col_predmet, "\n")
cat("  dist         ->", col_dist,    "\n")
cat("  rod          ->", col_rod,     "\n")
cat("  glas         ->", col_glas,    "\n")
cat("  prestiznost  ->", col_prest,   "\n")
cat("  redni_broj   ->", col_redni,   "\n\n")

# 2: Čuvanje samo redova koji odgovaraju eksperimentalnom delu (screen 2 koji sadrže response type "action")

  filter(
    Display          == "eksperimentalni_deo",
    Screen           == "Screen 2",
    Response.Type  == "action"
  ) %>%
  rename(
    participant_id = Participant.Private.ID,
    trial_number   = Trial.Number,
    rod            = !!col_rod,
    glas           = !!col_glas,
    prestiznost    = !!col_prest,
    item_id        = !!col_redni,
    img_a          = !!col_zan_m,
    img_b          = !!col_zan_z,
    img_c          = !!col_predmet,
    img_d          = !!col_dist
  ) %>%
  # ujednačavanje formata na string zarad sigurnije operacije "join" kasnije
  mutate(participant_id = as.character(participant_id), 
         prestiznost = ifelse(prestiznost == "z", "n", prestiznost) #greška "z" u samom kodiranju u eksperimentu, rekodiranje na tačnu oznaku
)

cat("Experimental action rows found:", nrow(metadata_action), "\n")
cat("Participants in metadata:",
    length(unique(metadata_action$participant_id)), "\n\n")


# ---- 3. TABELA ODGOVARAJUĆIH VREDNOSTI ZA AoIs ---------------------------
# svaki red ogovara jednoj rečenici jednog ispitanika u kome je ukodirano koja kategorija imenice je prikazana

trial_lookup <- metadata_action %>%
  distinct(participant_id, trial_number, item_id,
           rod, glas, prestiznost,
           img_a, img_b, img_c, img_d) %>%

    mutate(prestiznost = ifelse(prestiznost == "z", "n", prestiznost)
  ) %>%
  mutate(
    role_a = map_chr(img_a, classify_image),
    role_b = map_chr(img_b, classify_image),
    role_c = map_chr(img_c, classify_image),
    role_d = map_chr(img_d, classify_image)
  )

cat("Trial lookup built:", nrow(trial_lookup), "rows\n")

# provera: svaka rečenica ima tačno jednu kategoriju po prikazanoj poziciji (a - d)
role_check <- trial_lookup %>%
  rowwise() %>%
  mutate(role_set = paste(sort(c(role_a, role_b, role_c, role_d)),
                          collapse = "-")) %>%
  ungroup() %>%
  count(role_set)

cat("\nRole-set check (should be only 'MNA-ZNA-dist-predmet'):\n")
print(role_check)

# provera da li su sve kategorije uspešno klasifikovane (da li ima NA vrednosti)
na_rows <- trial_lookup %>%
  filter(if_any(c(role_a, role_b, role_c, role_d), is.na))
if (nrow(na_rows) > 0) {
  cat("\nWARNING:", nrow(na_rows),
      "trials have unclassified images.\n")
  cat("Check these image names against your stimulus lists:\n")
  print(na_rows %>% select(participant_id, trial_number,
                            img_a, img_b, img_c, img_d,
                            role_a, role_b, role_c, role_d))
} else {
  cat("\nAll images classified successfully.\n")
}
cat("\n")

# ---- 4. FUNKCIJA ZA OBRADU POJEDINAČNOG GAZE FAJLA----------------------

process_gaze_file <- function(filepath, lookup, bin_size = 50) {

  # učitavanje .csv fajla
  df <- tryCatch(
    read.csv(filepath, stringsAsFactors = FALSE),
    error = function(e) NULL
    )   
  if (is.null(df) || nrow(df) == 0) return(NULL)

  # 3: isključivanje svih "skrinova" koji nisu eksperimentalni deo (npr. uputstva, kalibracija, vežbe-triali)
  
  display_vals <- unique(df$Display)
  if (!"eksperimentalni_deo" %in% display_vals) return(NULL)
  
  # identifikovanje ključa ispitanika i broja rečenice (eksperimentalnog stimulusnog ajtema)
  participant_id <- as.character(unique(df$Participant.Private.ID))
  trial_number   <- unique(df$Trial.Number)

  # za slučaj da jedan fajl ima dupliran broj ajtema, biranje prvog (safety net korak, ne bi trebalo da postoji takav fajl)
  if (length(trial_number) > 1) return(NULL)
  

  # --- dodeliti svakoj zoni njen label (a-d) i sačuvati koordinate ---
  zones <- df %>%
    filter(
      Type == "zone",
      Zone.Name %in% c("TopLeft", "TopRight", "BottomLeft", "BottomRight")
    ) %>%
    select(Zone.Name, Zone.X, Zone.Y, Zone.W, Zone.H) %>%
    mutate(zone_label = recode(Zone.Name,
                               "TopLeft"     = "a",
                               "TopRight"    = "b",
                               "BottomLeft"  = "c",
                               "BottomRight" = "d"))

  if (nrow(zones) == 0) return(NULL)
  

  # --- identifikacija redova sa predikcijama koordinata pogleda (cf. gorilla experiment builder) ---
  preds <- df %>%
    filter(Type == "prediction") %>%
    select(
      Elapsed,
      gaze_x = Predicted.Gaze.X,
      gaze_y = Predicted.Gaze.Y
    ) %>%
    filter(!is.na(gaze_x), !is.na(gaze_y)) %>%
    arrange(Elapsed) %>%
    distinct(Elapsed, .keep_all = TRUE)   # uklanjanje vremenskih duplikata (ako postoje)

  if (nrow(preds) < 5) return(NULL)
  
  # --- interpoliranje vremenskih intervala u jednake intervale od 50ms ---
  time_grid <- seq(min(preds$Elapsed), max(preds$Elapsed), by = 10)

  gaze_interp <- data.frame(
    elapsed = time_grid,
    gaze_x  = approx(preds$Elapsed, preds$gaze_x,
                     xout = time_grid, method = "linear", rule = 1)$y,
    gaze_y  = approx(preds$Elapsed, preds$gaze_y,
                     xout = time_grid, method = "linear", rule = 1)$y
  )

  # --- klasifikacija svake predviđene tačke u zonu a,b,c ili d ---
  classify_gaze_point <- function(x, y, zones_df) {
    if (is.na(x) || is.na(y)) return("none")
    for (i in seq_len(nrow(zones_df))) {
      z <- zones_df[i, ]
      if (x >= z$Zone.X && x <= (z$Zone.X + z$Zone.W) &&
          y >= z$Zone.Y && y <= (z$Zone.Y + z$Zone.H)) {
        return(z$zone_label)
      }
    }
    return("none")
  }

  gaze_interp$zone_hit <- mapply(
    classify_gaze_point,
    gaze_interp$gaze_x,
    gaze_interp$gaze_y,
    MoreArgs = list(zones_df = zones)
  )

    # --- uvezivanje koordinata sa time koja slika je u datoj zoni
    # predstavljena u svakoj rečenici ovom ispitaniku ---
  trial_info <- lookup %>%
    filter(
      participant_id == !!participant_id,
      trial_number   == !!trial_number
    ) %>%
    as.data.frame() %>%
    head(1)

  if (nrow(trial_info) == 0) {
    cat("  WARNING: no metadata match — participant", participant_id,
        "trial", trial_number, "skipping\n")
    return(NULL)
  }

  # povezivanje zona x kategorija slike-imenice
  role_map <- c(
    "a"    = trial_info$role_a,
    "b"    = trial_info$role_b,
    "c"    = trial_info$role_c,
    "d"    = trial_info$role_d,
    "none" = "none"
  )
  gaze_interp$aoi_role <- recode(gaze_interp$zone_hit, !!!role_map)

  # --- "binning" u vremenske intervale od 50ms ---
  gaze_binned <- gaze_interp %>%
    mutate(time_bin = floor(elapsed / bin_size) * bin_size) %>%
    group_by(time_bin) %>%
    summarise(
      n_MNA     = sum(aoi_role == "MNA",     na.rm = TRUE),
      n_ZNA     = sum(aoi_role == "ZNA",     na.rm = TRUE),
      n_predmet = sum(aoi_role == "predmet", na.rm = TRUE),
      n_dist    = sum(aoi_role == "dist",    na.rm = TRUE),
      n_none    = sum(aoi_role == "none",    na.rm = TRUE),
      n_total   = n(),
      .groups   = "drop"
    ) %>%
    mutate(
      # Empirical logit — positive = more looks to female referent
      #zavisna varijabla -- logaritam odnosa pogleda prema ZNA i MNA (pozitivan = više pogleda prema ZNA)
      elogit = log((n_ZNA + 0.5) / (n_MNA + 0.5)),
      # Težina - inverzna varijansa
      weight = 1 / ((1 / (n_ZNA + 0.5)) + (1 / (n_MNA + 0.5))),
      # uvezivanje nezavisnih varijabli iz metapodataka
      participant_id = participant_id,
      trial_number   = trial_number,
      item_id        = trial_info$item_id,    
      rod            = trial_info$rod,
      glas           = trial_info$glas,
      prestiznost    = trial_info$prestiznost
    )

  return(gaze_binned)
}


# ---- 5. učitavanje svih .csv fajlova -------------------------
cat("\n--- FINDING FILES ---\n")

all_files <- list.files(
  path       = here("data", "raw", "gaze_csv"),
  pattern    = "\\.csv$",
  full.names = TRUE
)
cat("Total CSV files found:", length(all_files), "\n\n")

# ---- 6. PIPELINE (pozivanje funkcije za sve fajlove)---------------------------------------
n_files   <- length(all_files)
data_list <- vector("list", n_files)

cat("Starting processing of", n_files, "files...\n")
t_start <- Sys.time()

for (i in seq_along(all_files)) {

  data_list[[i]] <- process_gaze_file(all_files[[i]], trial_lookup,
                                       bin_size = 50)

  # provera: update o napretku na svakih 100 fajlova

  if (i %% 100 == 0 || i == n_files) {
    elapsed <- round(difftime(Sys.time(), t_start, units = "mins"), 1)
    n_done  <- sum(!sapply(data_list[1:i], is.null))
    cat(sprintf("  [%d / %d] %.1f min elapsed | %d experimental files processed\n",
                i, n_files, as.numeric(elapsed), n_done))
  }
}

cat("\n--- COMBINING RESULTS ---\n")

data_all <- data_list %>%
  compact() %>%           
  bind_rows()

cat("Final data dimensions:", nrow(data_all), "rows x",
    ncol(data_all), "cols\n")
cat("Participants processed:",
    length(unique(data_all$participant_id)), "\n")
cat("Trials processed:",
    length(unique(paste(data_all$participant_id,
                        data_all$trial_number))), "\n")
cat("Time bins per trial (approx):",
    round(nrow(data_all) /
            length(unique(paste(data_all$participant_id,
                                data_all$trial_number)))), "\n\n")

# opseg logaritma (provera ekstremni vrednosti)
cat("Elogit summary:\n")
print(summary(data_all$elogit))

# provera da li ima NA vrednosti u koloni logaritma (zavisne varijabe)
n_na <- sum(is.na(data_all$elogit))
if (n_na > 0) cat("WARNING:", n_na, "NA elogit values\n")

# ---- 7. eksportovanje u fajl sa rezultatima ------------------------------
output_path <- here("data", "processed", "gaze_binned_FULL.csv")

write.csv(data_all, output_path, row.names = FALSE)

cat("\nExported to:", output_path, "\n")
cat("\nFirst few rows:\n")
print(head(data_all, 10))