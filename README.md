# Predikcije tokom kognitivne obrade muških i ženskih nomina agentis u srpskom jeziku – na preseku pola, roda i prestižnosti

## Sažetak projekta

Ovaj projekat predstavlja analizu podataka prikupljenih u okviru istraživanja sprovedenog u Istaživačkoj stanici Petnici krajem 2025. godine. 
Sprovedeno je od strane polaznice Sare Tešić, pod mentorstvom Sare Barać i stručne saradnice dr Bojane Ristić. 

U ovom projektu je provedena longitudinalna analiza **(Growth Curve Analysis)** sa ciljem utvrđivanja:

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

### primer eksperimentalnog ekrana

Četiri ilustracije su bile prikazivane na ekranu, uvek randomizovane: 
1) ilustracija zanimanja muškog pola
2) ilustracija zanimanja ženskog pola
3) predmet-objekat sadržan u eksperimentalnoj rečenici
4) distraktor predmet


</td>
</tr>
</table>
---

## 📊 Procedura i komentari o metodološkoj postvci eksperimenta:

📌 rečenice raspoređene Latinskim kvadratom u dve verzije eksperimenta -- jedan ispitanik_ca videli sve uslove i sve rečenice, ali ne uvek u istom uslovu (kombinaciji nivoa kategoričkih varijabli)

📌 imenica nomina agentis uvek na kraju rečenice, izgovarana muškim i ženskim glasom

📌 ilustracije prikazivane randomizovano u za svakog ispitanika za svaku rečenicu kako bi se izbegao efekat uvežbavanja ispitanika 

## 📊 Izgled "raw" output-a

1. **data_exp_249742-v1_tasks.csv** --> primer fajla: 

   Fajl sa metapodacima:

   _Participant Private ID:_ ključ identifikacije ispitanika
   
   _Response:_ kolona u kojoj se identifikuje **a, b, c** ili **d** "Area of interest (AoI)", odnosno segment ekrana u kome je ilustracija
   
   _NB: Nomenklatura je posledica imenovanja kolona u samom Gorilla softveru, ove kolone u .csv fajlu su sadržale informacije o tome:_
   
   _Spreadsheet: zanimanje m_ : šta je prikazano u gornjem levom uglu ekrana (dakle, koja imenica konkretno)
   
   _Spreadsheet: zanimanje ž_ :  šta je prikazano u gornjem desnom uglu ekrana
   
   _Spreadsheet: predmet_ :  šta je prikazano u donjem levom uglu ekrana
   
   _Spreadsheet: dist_:  šta je prikazano u donjem desnom uglu ekrana

2. **data_exp_249742-v1_questionnaires.csv** --> primer fajla:

   _Participant Private ID_: ključ identifikacije ispitanika
   
   _Response:_ 1 - muški pol, 2 - ženski pol, 3 - ne želim da se izjasnim (kasnije isključeni iz analize)

3. **gaze_csv**:

   folder koji je sadržao .csv fajlove sa koordinatama predikcije (usled prirode funkcionisanja Gorilla-e) pogleda za svaku rečenicu za svakog ispitanika:

   249742-1-14607260-task-dqd7-50883952-calibration-1-2.csv (ekrani za kalibraciju pogleda -- nisu uključeni u analizu)
   
   249742-1-14607260-task-dqd7-50883952-collection-3-2.csv
   
   249742-1-14607260-task-dqd7-50883952-collection-4-2.csv
   
   .
   
   .
   
   .
   
   2849 fajlova   

## 📊 Analiza podataka (pipeline analize)

## Pretprocesiranje podataka

```mermaid
flowchart LR

subgraph INPUT podaci
A[data_exp_249742-v1_tasks.csv]
B[gaze_csv]
end
 
subgraph pretprocesiranje
C[01_preprocess_TEST.R]
end

subgraph BAZA PODATAKA
D[gaze_binned_FULL.csv]
end

subgraph uklanjanje nevalidnih ispitanika
E[02_exclusions.R]
end

subgraph BAZA VALIDNIH ISPITANIKA
F[gaze_binned_CLEAN.csv]
end

subgraph uvrštavanje pola ispitanika
G[04_gender.R]
end

subgraph BAZA SA KODIRANIM POLOM ISP.
H[gaze_binned_gender.csv]
end

A --> C
B --> C
C --> D --> E --> F --> G --> H

```

### Tok pripreme baze podataka

1. **data_exp_249742-v1_tasks.csv**  
Iz ovog fajla izračunato za svaku rečenicu za svakog ispitanika --  koja je imenica (tačnije da li ŽNA, MNA, distraktor ili predmet) bila u kom AoI (a, b, c ili d). (cf. randomizacija prikazanih ilustracija)

2. **gaze_csv**  


4. **gaze_binned_FULL.csv**  
povezani uslovi za svakog ispitanika, pogled interpoliran i razdvojen na jednake vremenske intervale

6. **gaze_binned_CLEAN.csv**  
isključivanje nevalidnih ispitanika i netačnih pojedinačnih odgovora

8. **gaze_binned_gender.csv**  
povezivanje pola ispitanika sa njihovim odgovorima na osnovu podataka iz data_exp_249742-v1_questionnaires.csv
---

```mermaid
flowchart LR

A[gaze_binned_CLEAN.csv]

A -->|Main analysis| B[model_main.R]
A -->|Gender analysis| C[gaze_binned_gender.csv]

C --> D[model_gender.R]

B --> E[Base GCA model]
D --> F[Gender-extended GCA model]
```

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
