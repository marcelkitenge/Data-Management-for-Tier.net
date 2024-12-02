

global DATA = "/Users/marcelkitenge/Documents/Doctoral/PhD 2021/Data/DES Export/19August2021"

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

bysort patient(visit_date) : egen DoFVFac=min(visit_date)
format DoFVFac %tdDD/NN/CCYY


bysort patient(visit_date) : gen time_visit=visit_date-visit_date[_n-1]



gen LTFU=.
replace LTFU=1 if time_visit>=90  // interruption >= 90 days
replace LTFU=2 if time_visit<89   // regular attendance 
replace LTFU=. if time_visit==.   

br patient DoLVFac visit_date patient_N patient_n time_visit LTFU if LTFU==. // Those are patients with fist visit, time_visit and LTFU shold be missing. 
tab LTFU, m


drop patient_N patient_n
rename patient, upper

keep if time_visit!=.

drop ctx inh tb_status subclinic examiner monthsprescribed user_defined_visit_var2 user_defined_visit_var3 who_stage user_defined_visit_var1 pregnancy visit_fac

save "$DATA1/Visits-Attendance.dta", replace


*** Open Data with AHD ***

use "$DATA1/TIER_Final-wide.dta" , clear
keep if AHD==2

count 

keep AHD PATIENT minDate_Exper2

merge 1:m PATIENT using "$DATA1/Visits-Attendance.dta"
keep if _merge==3

sort  PATIENT

keep if visit_date<minDate_Exper2

bysort PATIENT (visit_date) : egen first=min(visit_date)
format first %td

keep if first==visit_date
duplicates tag PATIENT, gen(tag)

tab tag 

quietly bysort PATIENT first :  gen dup2 = cond(_N==1,0,_n)

tab dup2 // 66 duplicates 
br 
drop if dup2>=2

keep PATIENT first LTFU

save "$DATA1/AHDeXperienced-fac_attend.dta", replace
noi{
***** END OF PROGRAM  **** 
}
