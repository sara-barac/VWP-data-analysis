# Predikcije tokom kognitivne obrade muških i ženskih nomina agentis u srpskom jeziku – na preseku pola, roda i prestižnosti

## Sažetak projekta

Ovaj projekat predstavlja analizu podataka prikupljenih u okviru istraživanja sprovedenog u Istaživačkoj stanici Petnici krajem 2025. godine. 
Sprovedeno je od strane polaznice Sare Tešić, pod mentorstvom Sare Barać i stručne naučne konsultantkinje dr Bojane Ristić. 

Sprovedena je longitudinalna analiza **(Growth Curve Analysis)** sa ciljem utvrđivanja:

Kako:
1)  pol ispitanika
2)  rod imenice 
3)  glas kojim se imenica predstavlja 
4)  prestižnost predstavljenog zanimanja 

i(li) međusobna interakcija ovih faktora

utiču na pokrete očiju ispitanika govornika_ca srpskog jezika?

## Teorijsko-metodološka pozadina  

📌 Psiholingvistička pilot-studija na srpskom jeziku, zasnovana na prethodnim istraživanjima koja pokazuju da pokreti očiju oslikavaju obradu jezika

📌 Materijal: **12** rečenica sa imenicom nomino agentis u (a) muškom rodu, (b) ženskom rodu, koje su (6) prestižnih zanimanja i (6) neprestižnih zanimanja, svih pročitanih i muškim i ženskim glasom. 
Ukupan materijal latinskim kvadratom raspoređen u dve verzije eksperimenta. 

primer stimulusne rečenice: *Akvarijum će pre godišnjeg napuniti bibliotekar.*

📌 Podaci prikupljeni u softveru za praćenje pokrera očiju u *broswer*-u (na bazi *web-gazer*-a) -- **Gorilla Experiment Builder**

📌 Eksperimentalni ekran tokom kog su praćeni pokreti očiju:

<table>
<tr>
<td width="40%">

<img src="pictures/example_screen.png" width="100%">

</td>

<td width="60%">

### primer eksperimentalnog ektrana

Četiri ilustracije su bile prikazivane na ekranu, uvek randomizovane: 
1) ilustracija zanimanja muškog pola
2) ilustracija zanimanja ženskog pola
3) predmet-objekat sadržan u eksperimentalnoj rečenici
4) distraktor predmet


</td>
</tr>
</table>
---


## 📊 Analiza podataka (pipeline analize)

## Pretprocesiranje podataka (autput fajlova iz *Gorilla*-e)

```mermaid
flowchart LR

subgraph INPUT podaci
A[data_exp_249742-v1_tasks.csv]
B[gaze_csv]
end

subgraph PREPROCESSING
C[gaze_binned_FULL.csv]
end

subgraph cleaning nonvalid trials
D[gaze_binned_CLEAN.csv]
end

subgraph ANALYSIS
E[gaze_binned_gender.csv]
end

A --> C
B --> C
C --> D --> E
```

### Workflow description

1. **tasks.csv**  
   Metadata file containing experimental sentences and illustration positions for each participant and trial.

2. **gaze_csv**  
   Raw gaze-coordinate predictions for all participants across experimental trials.

3. **gaze_binned_FULL.csv**  
   Merged dataset with aligned conditions, interpolated gaze trajectories, and equal time bins.

4. **gaze_binned_CLEAN.csv**  
   Dataset after exclusion of invalid participants and incorrect responses.

5. **gaze_binned_gender.csv**  
   Final dataset enriched with participant gender information from questionnaire metadata.



```mermaid
flowchart LR

%% ===== COMMENTS =====

A_note["Fajl u kome se nalaze metapodaci o prikazanim rečenicama i pozicijama ilustracija za datog ispitanika u datom *trial*-u"]
B_note["folder sa pojedinačnim koordinatama (tačnije predikcijama) pogleda za svakog ispitanika za sve eksperimentalne rečenice"]
C_note["povezani uslovi za svakog ispitanika, pogled interpoliran i razdvojen na jednake vremenske intervale"]
D_note["isključivanje nevalidnih ispitanika i netačnih pojedinačnih odgovora"]
E_note["povezivanje pola ispitanika sa njihovim odgovorima na osnovu podataka iz data_exp_249742-v1_questionnaires.csv"]

%% ===== MAIN NODES =====

A[fajl **data_exp_249742-v1_tasks.csv**]
B[data/raw/gaze_csv]
C[gaze_binned_FULL.csv]
D[gaze_binned_CLEAN.csv]
E[gaze_binned_gender.csv]

%% ===== FLOW =====

A --> C 
B --> C 
C --> D --> E 

%% ===== COMMENT LINKS =====

A_note -.-> A
B_note -.-> B
C_note -.-> C
D_note -.-> D
E_note -.-> E

```

```mermaid
flowchart LR

%% =========================
%% PRETPROCESIRANJE
%% =========================

subgraph PREPROCESSING

A_note["Remove calibration files<br/>Exclude invalid recordings"]
A[Raw Tobii CSV files]

B_note["Extract experimental trials<br/>Keep relevant events only"]
B[Trial extraction]

C_note["Assign AOIs<br/>Prepare fixation coordinates"]
C[AOI processing]

D_note["Synchronize timestamps<br/>Align gaze samples"]
D[Time alignment]

end

%% =========================
%% TRANSFORMATION
%% =========================

subgraph TRANSFORMATION

E_note["Aggregate gaze data<br/>Create time bins"]
E[Time binning]

F_note["Calculate fixation proportions<br/>Target vs competitor"]
F[Fixation proportions]

G_note["Stabilize variance<br/>Empirical logit transformation"]
G[Empirical logits]

end

%% =========================
%% ANALYSIS
%% =========================

subgraph ANALYSIS

H_note["Fit mixed-effects models<br/>Growth Curve Analysis"]
H[Growth Curve Analysis]

I_note["Generate plots<br/>Interpret trajectory dynamics"]
I[Visualization]

end

%% =========================
%% MAIN FLOW
%% =========================

A --> B --> C --> D --> E --> F --> G --> H --> I

%% =========================
%% COMMENT LINKS
%% =========================

A_note -.-> A
B_note -.-> B
C_note -.-> C
D_note -.-> D
E_note -.-> E
F_note -.-> F
G_note -.-> G
H_note -.-> H
I_note -.-> I
```
---

## Repository Structure

```text
project/
│
├── README.md
│
├── data/
│   └── example/
│
├── scripts/
│   ├── 01_data_cleaning.R
│   ├── 02_trial_processing.R
│   ├── 03_time_binning.R
│   ├── 04_empirical_logits.R
│   ├── 05_gca_analysis.R
│   └── 06_visualization.R
│
├── figures/
│
└── results/
```

---

## Methods

### Experimental Paradigm

- Visual World Paradigm (VWP)
- Tobii Eye Tracker 5
- Serbian nominal agent forms

### Statistical Analysis

Analyses were conducted in R using:

- Growth Curve Analysis (GCA)
- Linear mixed-effects models
- Orthogonal time polynomials
- Empirical logit transformation

Main packages:

```r
library(tidyverse)
library(lme4)
library(lmerTest)
library(ggplot2)
```

---

## Reproducing the Analysis

Run scripts in the following order:

1. `01_data_cleaning.R`
2. `02_trial_processing.R`
3. `03_time_binning.R`
4. `04_empirical_logits.R`
5. `05_gca_analysis.R`
6. `06_visualization.R`

---

## Example Data

For repository size and privacy reasons, only example datasets are included.

The `data/example/` directory contains small representative samples demonstrating the structure of the original data.

---

## Example Output

Example trajectory plots and statistical outputs are available in:

```text
figures/
results/
```

---

## Author

Sara Barać

Faculty project repository.
