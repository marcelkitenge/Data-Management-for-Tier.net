set more off
global DATA = "/Users/marcelkitenge/Documents/Doctoral/PhD 2021/Data/DES Export/19August2021"
global DATA1 ="/Users/marcelkitenge/Documents/Doctoral/PhD 2021/Data"

//log using "$DATA1/Data Cleaning.log", replace


*************************************************************************************************************
** PROCESS TIER DES EXPORT******
********************************************VIS*****************************************************************
import delimited "$DATA/VIS.txt", bindquote(strict) clear 

*** Opening visit
generate  visit_date=date(visit_dmy,"YMD")
format visit_date %tdDD/NN/CCYY

generate next_VisDate=date(next_visit_dmy,"YMD")
format next_VisDate %tdDD/NN/CCYY

drop  visit_dmy next_visit_dmy

bysort patient (visit_date): gen patient_N=_N
bysort patient (visit_date): gen patient_n=_n
br patient_N patient_n

bysort patient(visit_date): gen DoLVFac = visit_date[_N] 
format DoLVFac %tdDD/NN/CCYY

keep if patient_n==patient_N
drop patient_N patient_n
rename patient, upper
save "$DATA1/Visits.dta", replace

*********************************************DEMO******************************************************************
import excel "$DATA\DEM.xlsx", sheet("DEM") firstrow clear 
keep PATIENT FOLDER_NUMBER OTHER_NUMBER SURNAME FIRST_NAME
duplicates report PATIENT

save "$DATA1/DEM.dta", replace

*********************************************PAT******************************************************************

import excel "$DATA\PAT.xlsx", sheet("PAT") firstrow clear
keep PATIENT FACILITY BIRTH_DMY GENDER FRSVIS_DMY HIVP_DMY HAART_DMY OUTCOME OUTCOME_DMY FHV_STAGE_WHO EXP_Y METHOD_INTO_ART TRANSFER_IN_DMY TB_FHV

gen DoFV = date( FRSVIS_DMY, "YMD") //Date of first visit 
gen DoHIV = date(HIVP_DMY , "YMD") // date of HIV diagnosis 
gen DoO = date(OUTCOME_DMY , "YMD") // date of outcomes
gen DoB = date(BIRTH_DMY, "YMD")
gen DoAS = date(HAART_DMY,"YMD") //date of ART initiation
gen DoTI= date(TRANSFER_IN_DMY,"YMD") // date of transfer in 
gen DoFHIV=date(HIVP_DMY,"YMD") //date of first HIV positive 


format %tdDD/NN/CCYY DoFV DoHIV DoO DoB DoAS DoTI DoFHIV
drop FRSVIS_DMY HIVP_DMY OUTCOME_DMY BIRTH_DMY HAART_DMY TRANSFER_IN_DMY


*** Date first visit at the facility: 
*** data capture for the first visit is inconsistent. 
*** not all DOH data capturers actually do the same

gen DoFVFac = .
format DoFVFac %tdDD/NN/CCYY
label var DoFVFac "Date of First Visit at the Facility"

*** 1. We consider date of transfer as first contact with current facility
*** (e.g. some patient have a first visit anterior to TI because capturer accounted for the reference letter) 
replace DoFVFac = DoTI if DoFVFac == .
*** 2. We consider remaining First visit date as first contact for registered in PreART
replace DoFVFac = DoFV if DoFVFac == .
*** 3. We consider Do ART start if none of the 2 previous dates are present (initiation at first visit) 
replace DoFVFac = DoAS if DoFVFac == .


save "$DATA1/PAT.dta", replace

*********************************************LAB******************************************************************

import delimited "$DATA/LAB.txt", bindquote(strict) clear 
keep patient lab_dmy lab_id lab_v
rename *, upper

gen Lab_Date = date(LAB_DMY,"YMD") //date of ART initiation
format %tdDD/NN/CCYY Lab_Date
br
bysort PATIENT LAB_ID(LAB_DMY): gen PATIENT_N= _N
bysort PATIENT LAB_ID(LAB_DMY): gen PATIENT_n= _n

keep if LAB_ID=="CD4A" 
//| LAB_ID=="RNA"

destring LAB_V, replace 


keep PATIENT LAB_V Lab_Date LAB_ID

**date result last CD4
 
bysort PATIENT (Lab_Date): gen CD4Date_last = Lab_Date[_N] 
format %td CD4Date_last

bysort PATIENT (Lab_Date): gen CD_last = LAB_V[_N] 

 
***1st low CD4 date
gen CD4_low=Lab_Date if LAB_V<200
format %td CD4_low 


sort PATIENT CD4_low
by PATIENT: egen CD4_low_1time= min(CD4_low)  

format %td CD4_low_1time

bysort PATIENT(Lab_Date): gen PATIENT_n= _n

 
* Generating time to subsequent lab tests*

bysort PATIENT(Lab_Date) : gen time= Lab_Date-Lab_Date[_n-1]
gen CD4_1timevalue=LAB_V if CD4_low!=. & PATIENT_n==1 

** Genrating Advanced HIV Disease Patients 
gen AHD=.
replace AHD=0 if CD4_low==. & PATIENT_n==1 
replace AHD=1 if CD4_low!=. & PATIENT_n==1 // those presenting with CD4,0
replace AHD=2 if CD4_low!=. & CD4_1timevalue==. & PATIENT_n>=1 & time>=90
tab AHD

**** Generating ART-experienced *****

gen subs_lowCD4value=LAB_V if CD4_low!=. & CD4_1timevalue==. & PATIENT_n>=1

bysort PATIENT (Lab_Date): gen AHD_exper_date= Lab_Date if AHD==2
format %td AHD_exper_date

br 

/*
gen AHD_experienced=LAB_V & CD4_low!=. & CD4_1timevalue==. & PATIENT_n>=1
replace AHD_experienced=0 if AHD_Naive==1 & AHD_experienced!=1
replace AHD_experienced=. if AHD_Naive==1

tab AHD_experienced, m
*/

** Asseing for duplicates for both ART-Naive and ART-expereinced patients ******

duplicates tag PATIENT if AHD ==1 , generate(tag_Naive)
tab tag_Naive // No duplicates for those ART-naive patients with AHD 

duplicates tag PATIENT if AHD ==0 , generate(tag_Naive1)
tab tag_Naive1 // No duplicates for those ART-naive patients without AHD

duplicates tag PATIENT if AHD ==2, gen(tag_experienced)
tab tag_experienced // several duplicates as expetcted 

quietly by PATIENT Lab_Date:  gen dup_experienced = cond(_N==1,0,_n) if AHD ==2
tab dup_experienced // These codes produce similar outpus as above codes, first episode of CD4<200 cells/ml following >=200 cells at presentation should be included in the analysis. 

*** Let include 1st episode of CD4<200 cells/ml decline among ART-experienced ****

bysort  PATIENT (Lab_Date) : egen minDate_Exper=min(Lab_Date) if AHD==2 // Identifying fist ever decline of CD4<200 cells/ml among ART-experienced
format minDate_Exper Lab_Date %td

count if Lab_Date==minDate_Exper // These patients should be included
count if Lab_Date!=minDate_Exper // These should ignored 

br PATIENT AHD minDate_Exper Lab_Date PATIENT_n LAB_V

** Only keeping these  with 1st episode of CD4 decline < 200 cells/ml **

replace AHD=. if Lab_Date!=minDate_Exper & PATIENT_n>1 

/*
Considereing the above challenge related to duplicates among ART-experienced. One should consider method or startegies proposed by Dr Fatti, which consists by including CD4 count results with 3-6 month window follieing ART initiation. As such, if more than one CD4 measure was taken in the window period,the latest is considered. the following steps are followed : 
1.  Keep ART-Naive patients with AHD in a long format considering they are not duplicates in group. 
2. Process ART-experienced patients by reshaping this 
*/

br PATIENT LAB_V Lab_Date CD4_1timevalue AHD subs_lowCD4value PATIENT_n // Several duplicates as expected 

save "$DATA1/LAB_CD4Long.dta", replace

************* Change long to wide format **********

use "$DATA1/LAB_CD4Long.dta", clear 

duplicates tag PATIENT LAB_V Lab_Date, gen(TAG)
browse if TAG>=1
tab TAG


sort PATIENT LAB_V Lab_Date
quietly by PATIENT LAB_V Lab_Date:  gen dup2 = cond(_N==1,0,_n)
tab dup2
br PATIENT LAB_V Lab_Date dup2  

//drop if dup2>=2
tab dup2

drop dup2 TAG 
drop tag_Naive tag_Naive1 tag_experienced dup_experienced PATIENT_n CD4_1timevalue

*** Restructure *****

keep if AHD!=.

gsort PATIENT Lab_Date
by PATIENT: gen VLnum= _n

reshape wide Lab_Date LAB_V CD4_low time AHD  subs_lowCD4value AHD_exper_date minDate_Exper , i(PATIENT) j(VLnum)

replace AHD1=2 if AHD2==2 & minDate_Exper2!=.

drop AHD2 AHD_exper_date1 time1 subs_lowCD4value1 LAB_ID minDate_Exper1

rename AHD1 AHD

save "$DATA1/LAB_CD4wide.dta", replace


					***************************************************
*************************** Importing TB data table *************************
					***************************************************

import excel "$DATA/TB.xlsx", sheet("TB") firstrow clear

** TB treatment start date
count //18,405
gen TB_Rx_start_date=date(TB_START_DMY,"YMD")

br TB_Rx_start_date TB_START_DMY
format TB_Rx_start_date %td
label variable TB_Rx_start_date " TB treatment start date"

** TB registration date 
gen TB_Registrtion_date=date(REG_DMY,"YMD")
format TB_Registrtion_date %td
label variable TB_Registrtion_date "TB registration date"

**Tb Treatment end date 
gen TB_Rx_end_date=date(TB_END_DMY,"YMD")
format TB_Rx_end_date %td
label variable TB_Rx_end_date "Date of Outcomes"
order PATIENT REGID TB_Rx_start_date TB_Registrtion_date

drop TB_START_DMY REG_DMY TB_END_DMY CAT CLASS SITE REGIMEN RESISTANT REGID
duplicates report   // Yes duplicate
duplicates report PATIENT  // Yes duplicate

keep if TB_Rx_start_date!=.

bysort PATIENT(TB_Rx_start_date) : gen time= TB_Rx_start_date-TB_Rx_start_date[_n-1]
drop if time==0


sort PATIENT  TB_Rx_start_date
quietly by PATIENT TB_Rx_start_date :  gen dup1 = cond(_N==1,0,_n) // duplicates using TB treatment date , 

tab dup1 // Zero duplicate starting on same date, however there are patients with several TB episode  
duplicates report PATIENT

count // 5171 patients
count if time!=. // of which 247 are duplicate 

drop dup1 EPISODE_ID TB_Registrtion_date time TB_OUTCOME REG_TYPE

gsort PATIENT TB_Rx_start_date 
by PATIENT: gen VLnum= _n

reshape wide TB_Rx_start_date TB_Rx_end_date , i(PATIENT) j(VLnum)


save "$DATA1/TB.dta", replace

					*****************************
********************************* ART *************************************************
					*****************************

import excel "$DATA\ART.xlsx", sheet("ART") firstrow clear
keep PATIENT ART_ID REGIMEN_LINE ART_SD_DMY ART_ED_DMY
gen DoSArt_reg=date(ART_SD_DMY,"YMD")
format DoSArt_reg %td

bysort PATIENT (DoSArt_reg): gen patient_N1=_N
bysort PATIENT (DoSArt_reg): gen patient_n1=_n
br patient_N1 patient_n1

keep if patient_n1==1

gen REG_LINE=.
replace REG_LINE=1 if REGIMEN_LINE=="1"
replace REG_LINE=2 if REGIMEN_LINE=="2"
replace REG_LINE=3 if REGIMEN_LINE=="3"
replace REG_LINE=4 if REGIMEN_LINE=="4"

label define REG_LINE 1 "1st line" 2 "2nd line" 3 "3rd line" 4 "Stopped"
label values REG_LINE REG_LINE 
tab REG_LINE

drop REGIMEN_LINE patient_N1 patient_n1

sort PATIENT

save "$DATA1\ART.dta", replace

*********************************************MERGING DES TABLES****************************************************
use "$DATA1/DEM.dta", clear 
merge 1:1 PATIENT using "$DATA1/PAT.dta"
drop _merge

merge 1:1 PATIENT using "$DATA1/Visits.dta"
keep if _merge==3
drop _merge

merge 1:1 PATIENT using "$DATA1/LAB_CD4wide.dta"
//merge 1:1 PATIENT using "$DATA1/LAB.dta"
keep if _merge == 3
drop _merge

save "$DATA1/Tier_DES_Export.dta", replace

/*
					***************************************************
************************* 1. Importing TB Lab data table *************************
					***************************************************

import delimited "$DATA/LAB.txt", bindquote(strict)  clear 

rename *, upper


tab LAB_ID, m // Type of TB lab Test
*** Formating lab date
gen TB_test_DMY=date(LAB_DMY,"YMD")
format TB_test_DMY %td
label variable TB_test_DMY "TB test date" 

bysort PATIENT LAB_ID(TB_test_DMY): gen PATIENT_N= _N
bysort PATIENT LAB_ID(TB_test_DMY): gen PATIENT_n= _n

drop LAB_DMY 
tab LAB_T LAB_ID // always check this 

gen Bacterio_tes=. 
replace Bacterio_tes=1 if (LAB_T=="-" | LAB_T=="Contaminated" | LAB_T=="Indeterminate") & (LAB_ID=="TBC" | LAB_ID=="TBGE" | LAB_ID=="TBLP" | LAB_ID=="TBM" )
replace Bacterio_tes=2 if (LAB_T=="+" | LAB_T=="1+" | LAB_T=="2+" | LAB_T=="3+" | LAB_T=="Paucibacillary") & (LAB_ID=="TBC" | LAB_ID=="TBGE" | LAB_ID=="TBLP" | LAB_ID=="TBM" | LAB_ID=="MNTX")
replace Bacterio_tes=3 if ( LAB_T=="+") & (LAB_ID=="TBCD" | LAB_ID=="TBXR")
replace Bacterio_tes=4 if (LAB_T=="-" | LAB_T=="Indeterminate") & (LAB_ID=="TBCD" | LAB_ID=="TBXR")

label variable Bacterio_tes "Bacteriologically Test"
label define Bacterio_tes 1" Bact neg" 2 "bact pos" 3"Clin/Xray Pos" 4"Clin/Xray neg" 
label values Bacterio_tes Bacterio_tes
tab  LAB_T Bacterio_tes  , m

*** the following two tabs must give equal numbers or number of test conducted 
tab Bacterio_tes, m
tab LAB_T
tab LAB_T if LAB_ID=="TBC" | LAB_ID=="TBGE" | LAB_ID=="TBLP" | LAB_ID=="TBM" ///
 | LAB_ID=="TBCD" | LAB_ID=="TBXR", missing 
 
								********************************************
******************************** Bacteriological Confirmation of all cases **************************
								********************************************

gen Bact_confirmation=.
replace Bact_confirmation=1 if (LAB_T=="+" | LAB_T=="1+" | LAB_T=="2+" | LAB_T=="3+" | LAB_T=="Paucibacillary") & (LAB_ID=="TBC" | LAB_ID=="TBGE" | LAB_ID=="TBLP" | LAB_ID=="TBM" | LAB_ID=="MNTX" | LAB_ID=="LAM") // Bact confirmed 

replace Bact_confirmation=2 if  (LAB_T=="-" ) & (LAB_ID=="TBC" | LAB_ID=="TBGE" | LAB_ID=="TBLP" | LAB_ID=="TBM" | LAB_ID=="MNTX" | LAB_ID=="LAM") // Bacteriologically negative
replace Bact_confirmation=3 if ( LAB_T=="+") & LAB_ID=="TBCD" // clinical abnormality 
replace Bact_confirmation=4 if ( LAB_T=="+") & LAB_ID=="TBXR" // CXR abnormality
replace Bact_confirmation=5 if ( LAB_T=="-") & LAB_ID=="TBXR" // CXR negative

label variable Bact_confirmation "Bact confimation for all"
label define Bact_confirmation 1"1.Bact confirmed" 2"2.Bact negative" 3"3.Clinical abnormality" 4"4.CXR abonormality" 5"5.CXR negative"
label values Bact_confirmation Bact_confirmation
tab Bact_confirmation

*** the following two tabs must give equal numbers or number of test conducted 

tab LAB_T if (LAB_ID=="TBC" | LAB_ID=="TBGE" | LAB_ID=="TBLP" | LAB_ID=="TBM" | LAB_ID=="TBCD" | LAB_ID=="TBXR" | LAB_ID=="Paucibacillary" | LAB_ID=="TBS" & | LAB_ID=="TBXR" | LAB_ID=="LAM"), m 

count if (LAB_ID=="TBC" | LAB_ID=="TBGE" | LAB_ID=="TBLP" | LAB_ID=="TBM" | LAB_ID=="TBCD" | LAB_ID=="TBXR" | LAB_ID=="Paucibacillary" | LAB_ID=="TBS" & | LAB_ID=="TBXR" | LAB_ID=="LAM")

keep if (LAB_ID=="TBC" | LAB_ID=="TBGE" | LAB_ID=="TBLP" | LAB_ID=="TBM" | LAB_ID=="TBCD" | LAB_ID=="TBXR" | LAB_ID=="Paucibacillary" | LAB_ID=="TBS" & | LAB_ID=="TBXR" | LAB_ID=="LAM")

tab Bact_confirmation LAB_ID , m  // Only TB Testing is maintained 
count 

keep if Bact_confirmation!=.
drop if Bact_confirmation==2 | Bact_confirmation==5

*** To drop duplicate

sort EPISODE_ID EPISODE_TYPE TB_test_DMY
quietly by EPISODE_ID EPISODE_TYPE TB_test_DMY :  gen dup1 = cond(_N==1,0,_n) // Ascertaining TB Episode 


sort PATIENT LAB_V TB_test_DMY
quietly by PATIENT LAB_V TB_test_DMY :  gen dup2 = cond(_N==1,0,_n) // Ascertaining TB testing on the same date 

br dup1 dup2 PATIENT PATIENT_N PATIENT_n TB_test_DMY EPISODE_ID EPISODE_TYPE

tab dup2 
tab dup1

drop if dup2>=2

drop LAB_V LAB_T TB_DRUG DRUG_RES LAB_VSRES PATIENT_N PATIENT_n Bacterio_tes dup1 dup2 EPISODE_ID

duplicates report PATIENT  
duplicates report EPISODE_ID  
count 


sort PATIENT TB_test_DMY 
by PATIENT: egen max=min(TB_test_DMY)  


gsort PATIENT TB_test_DMY 
by PATIENT: gen VLnum= _n

reshape wide  LAB_ID EPISODE_TYPE EPISODE_ID TB_test_DMY Bact_confirmation , i(PATIENT) j(VLnum)


save "$DATA1/TB_Test_Long.dta", replace 
*/
*******************************************************************************************************************

use "$DATA1/Tier_DES_Export.dta", clear
//rename visit_date  DoLAV // date of last visit 
rename next_VisDate DoLNext // date of next appointment

rename OUTCOME Outcome
rename FACILITY Facility
rename FOLDER_NUMBER Foldernumber
replace Foldernumber = trim(Foldernumber)

replace Outcome = "Died" if Outcome == "11"
replace Outcome = "Transferred/Moved Out" if Outcome == "30"
replace Outcome = "Lost to Follow-up" if Outcome == "40"
replace Outcome = "uLFU" if Outcome == "41"
replace Outcome = "" if Outcome == "20"

gen FAC  = . 
replace FAC = 1 if Facility == "kz Eshowe Clinic" 
replace FAC = 2 if Facility == "kz King Dinuzulu Clinic"  
replace FAC = 3 if Facility == "kz Siphilile Clinic" 
replace FAC = 4 if Facility == "kz Mbongolwane Hospital"   
replace FAC = 5 if Facility == "kz Mathungela Clinic"  
replace FAC = 6 if Facility == "kz Ngudwini Clinic"  
replace FAC = 7 if Facility == "kz Ntumeni Clinic"  
replace FAC = 8 if Facility == "kz Osungulweni Clinic"   
replace FAC = 9 if Facility == "kz Samungu Clinic"  
replace FAC = 10 if Facility == "kz Eshowe Hospital"  
replace FAC = 11 if Facility == "kz Eshowe Mobile 1" 
replace FAC = 12 if Facility == "kz Eshowe Mobile 2" 
replace FAC = 13 if Facility == "kz Eshowe Mobile 3" 

label define FAC 1 "01. EGC" 2 "02. KDC" 3 "03. SIP" 4 "04. MBO" 5  "05. MAT" 6 "06. NGU" 7 "07. NTU" 8 "08. OSU" 9  "09. SAM" 10 "10. SIN" 11 "11. Emob1" 12 "12. Emob2" 13 "13. Emob3" 
label values FAC Facility


rename tb_status, upper

generate tbstatus=.
replace tbstatus=0 if TB_STATUS==0
replace tbstatus=2 if TB_STATUS==2
replace tbstatus=3 if TB_STATUS==3
replace tbstatus=4 if TB_STATUS==4
replace tbstatus=95 if TB_STATUS==95
replace tbstatus=99 if TB_STATUS==99
label var tbstatus "TB status on visit"
label define tbstatus 0"0.No symptoms" 2"2.symptoms (+) & sputum test done" 3"3.symptoms (+) but no sputum test" ///
			4"4.on TB Rx" 95"95.screening was not done" 99"99.unknown screening status", modify
label val tbstatus tbstatus

drop TB_STATUS 

**** WHO Stage ****

rename who_stage, upper

generate whostage=.
replace whostage=1 if WHO_STAGE==1
replace whostage=2 if WHO_STAGE==2
replace whostage=3 if WHO_STAGE==3
replace whostage=4 if WHO_STAGE==4
replace whostage=95 if WHO_STAGE==95
label var whostage "WHO staging at the visit"
label define whostage_lbl 1"1.stageI" 2"2.stageII" 3"3.stageIII" 4"4.stageIV" 95"95.not ascertained"
label val whostage whostage_lbl

drop WHO_STAGE
tab whostage

**** Cotrimoxazole ****

rename ctx, upper

generate ctx=.
replace ctx=0 if CTX==0
replace ctx=1 if CTX==1
replace ctx=95 if CTX==95
replace ctx=99 if CTX==99
label var ctx "cotrimoxazole status"
label define ctx_lbl 0"0.no" 1"1.yes" 95"95.not ascertained" 99"99.unknown", modify
label val ctx ctx_lbl 

drop CTX
tab ctx

**** Isoniazid ****

rename inh, upper 

generate inh=.
replace inh=0 if INH==0
replace inh=1 if INH==1
replace inh=95 if INH==95
replace inh=99 if INH==99
label var inh "isoniazid status"
label define inh_lbl 0"0.no" 1"1.yes" 95"95.not ascertained" 99"99.unknown"
label val inh inh_lbl

drop INH
tab inh

drop pregnancy SURNAME FIRST_NAME Foldernumber OTHER_NUMBER


**** Generating time in care for those still in care*****

gen TimeInCare=(DoLVFac-DoAS)/(365/12)
replace TimeInCare=round(TimeInCare, 1.0)
browse TimeInCare


*** Generating Time from treatment to outcome (death-LTFU and tranfer and move outcocm)

gen Outcome_time=(DoO-DoAS)/30
format Outcome_time %1.0f

**** Application of Eligibility Criteria : AGe, whether patients started ART ****

gen Age=(DoFVFac-DoB)/365.25
format Age %1.0f

count if DoFVFac==. // No missing info
count if DoB==.  // No missing  info


*** AGE at FIRST VISIT at the Facility ***
gen AgeFVFac = ((DoFVFac - DoB)/365.25)
replace AgeFVFac=round(AgeFVFac, 1.0)
//format AgeFVFac %1.0f


*** AGE at INITIATION ****
gen AgeINI = .
replace AgeINI = ((DoAS - DoB)/365.25) 
format AgeINI %1.0f


*** This is to get the last date of visit in the data base
*** that we take as the date of point = 
*** the date of last extraction =
*** the reference date to calculate early and late missed.

generate DatePoint=mdy(08,19,2021)
format DatePoint %td
gen age=(DatePoint-DoB)/365.2
format  age %1.0f

**** Apply the eligibility Criteria ****

destring , replace

label define GENDER 1 "Male"  2 "Female"
label val GENDER GENDER 

tab GENDER

encode Facility, generate(Facility_)
drop Facility
rename Facility_ Facility1

*** This allows to identify ART-experienced who have decline CD4 before ART 

replace AHD=0 if DoAS>=minDate_Exper2

gen AHD_naive=AHD
replace AHD_naive=0 if AHD==2

tab AHD_naive

order AHD AHD_naive

rename Outcome Outcome
save "$DATA1/TIER_Final-wide.dta", replace


noi{
***** END OF PROGRAM  **** 
}


