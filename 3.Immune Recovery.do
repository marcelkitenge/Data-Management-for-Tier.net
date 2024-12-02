/*
On the study outcomes is to assess to immune recovery, time from last CD4 <200 to the 1st  CD4 >350 during follow-up. 
*/
global DATA1 ="/Users/marcelkitenge/Documents/Doctoral/PhD 2021/Data"

use "$DATA1/LAB_CD4Long.dta", clear 

drop PATIENT_n

bysort PATIENT (Lab_Date): gen PATIENT_n=_n


*** Time to Immune Recovery ****

bysort PATIENT (Lab_Date): gen DoIR=Lab_Date if AHD!=0 & PATIENT_n>1 & LAB_V>350
format DoIR %td

gen IrCD4=LAB_V if DoIR!=.  // CD4 count 

** Identifying 1st CD4 >350 cells/mL

bysort PATIENT : egen FirstDoIR=min(DoIR)
format FirstDoIR %td

replace FirstDoIR=. if AHD==2
count if FirstDoIR!=.

br PATIENT DoIR IrCD4 FirstDoIR  LAB_V PATIENT_n

** Only kee those with Date of 1st CD4 >350 equals to Date of lab date ***

keep if Lab_Date==FirstDoIR

*** Removing duplicates ***

duplicates tag PATIENT, ge(tag)
tab tag  // duplicates for some reason 

quietly bysort PATIENT Lab_Date:  gen tag1 = cond(_N==1,0,_n)
tab tag1
drop if tag1>=2. // Removing duplicates

keep PATIENT FirstDoIR IrCD4 AHD

save "$DATA1/ImmuneRecovery.dta", replace

*** Merging the above data with Major Data ****	

use "$DATA1/TIER_Final.dta", clear

merge 1:1 PATIENT using "$DATA1/ImmuneRecovery.dta"

br PATIENT minDate_Exper1 CD4_low1 CD4_low2 FirstDoIR AHD if AHD!=0

gen TimetoIR=(FirstDoIR-CD4_low1)/30

drop _merge

save "$DATA1/TIER_Final+ImmuneRecovery.dta", replace

noi{
***** END OF PROGRAM  **** 
}
