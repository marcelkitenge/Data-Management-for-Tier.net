
global DATA = "/Users/marcelkitenge/Documents/Doctoral/PhD 2021/Data/DES Export/19August2021"
global DATA1 ="/Users/marcelkitenge/Documents/Doctoral/PhD 2021/Data"

import delimited "$DATA/LAB.txt", bindquote(strict) clear 
keep patient lab_dmy lab_id lab_v
rename *, upper

foreach var of varlist _all{
	rename `var' `=upper("`var'")'
}

gen Lab_Date = date(LAB_DMY,"YMD") //date of ART initiation
format %tdDD/NN/CCYY Lab_Date
br
bysort PATIENT LAB_ID(LAB_DMY): gen PATIENT_N= _N
bysort PATIENT LAB_ID(LAB_DMY): gen PATIENT_n= _n

keep if LAB_ID=="RNA"

destring LAB_V, replace 


keep PATIENT LAB_V Lab_Date LAB_ID

*----------------------- begin set up variables ------------------

rename Lab_Date DoVL 
rename LAB_V VL

drop LAB_ID
sort PATIENT DoVL

**duplicates 

duplicates tag PATIENT VL DoVL, gen(TAG)
browse if TAG>=1

sort PATIENT VL DoVL
quietly by PATIENT VL DoVL:  gen dup2 = cond(_N==1,0,_n)
tab dup2

br PATIENT VL DoVL dup2  

drop if dup2>=2


drop dup2 TAG 

bysort PATIENT (DoVL): gen PATIENT_N= _N 
bysort PATIENT (DoVL): gen PATIENT_n= _n

*** VL group 1 ***
gen VLgroup=. 
replace VLgroup= 1  if (VL!=. & VL<1000)  
replace VLgroup= 2  if (VL!=. & VL>=1000) 

label define VLgroup  1 "1. <1000cp/ml" 2 "2. >=1000cp/ml" 

label values VLgroup VLgroup

save "$DATA1/VL-Long.dta", replace



merge m:m PATIENT using "$DATA1/TIER_Final-wide.dta"

keep if _merge==3
format DoVL %td

** Dropinig any VL date before date AHD diagnosis **

bysort PATIENT (DoVL) : egen MinDate=min(DoVL) // first ever VL testing 
format MinDate %td

br PATIENT DoVL minDate_Exper2 if DoVL<minDate_Exper2 & minDate_Exper2!=.

keep if DoVL<=minDate_Exper2 & minDate_Exper2!=.

br PATIENT DoVL minDate_Exper2 MinDate AHD VL

/*
Generate date of VL and CD4 testing that are similar 
These dates are at which patients with AHD experienced were detected
*/
gen HighVl=minDate_Exper2==DoVL & AHD==2


gen time=minDate_Exper2-DoVL

bysort PATIENT (DoVL): gen Tx_failure=VL[_n-1]>=1000 & minDate_Exper2!=. & PATIENT_n>1 & time<=450 // two consecutive VL >=1000 copies/mL

replace Tx_failure=2 if VL>=1000 & minDate_Exper2!=. & PATIENT_n>1 & HighVl==1 & Tx_failure!=1 // Single Vl >=1000 copies/mL
replace Tx_failure=0 if VL<1000 & minDate_Exper2!=. & PATIENT_n>1 & HighVl==1 // VL <1000 copies/mL


tab Tx_failure

br PATIENT AHD AHD_naive VL VLgroup PATIENT_N PATIENT_n DoVL minDate_Exper2 time HighVl Tx_failure
br PATIENT AHD AHD_naive VL VLgroup PATIENT_N PATIENT_n DoVL minDate_Exper2 time HighVl Tx_failure if AHD==2


quietly bysort PATIENT Tx_failure :  gen dup2 = cond(_N==1,0,_n)

drop if dup2>=2

tab dup2

keep PATIENT VL DoVL Tx_failure


gsort PATIENT DoVL
by PATIENT: gen VLnum= _n

reshape wide VL DoVL Tx_failure, i(PATIENT) j(VLnum)


*** Generating a signle VL test result from the 3 Tx_failure 1-2-3

replace Tx_failure1=. if Tx_failure2!=. | Tx_failure3!=. // we will consider the recent VL rest

gen VL_result=Tx_failure1
replace VL_result=Tx_failure2 if Tx_failure1==.
replace VL_result=Tx_failure3 if Tx_failure3!=. // Only considering the recent VL results 

count if VL2<1000 & VL_result==1 // 66 patients are labelled having 2 consecutive VL tests >=1000, while the last VL <1000 
replace VL_result=0 if VL2<1000 & VL_result==1 // This line deals with above problem. 

*** Generatiing date of VL result *****

gen DoVL= DoVL1

format DoVL %td


replace DoVL=DoVL2 if DoVL2!=.
br DoVL2 DoVL if DoVL2!=.

replace DoVL=DoVL3 if DoVL3!=.
br DoVL3 DoVL if DoVL3!=.

count if DoVL==.
rename DoVL DoVL_Result



keep PATIENT VL_result DoVL_Result

save "$DATA1/VLData-VTF_Wide.dta", replace

**** *** 
