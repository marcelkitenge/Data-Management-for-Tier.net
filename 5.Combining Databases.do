
global DATA1 ="/Users/marcelkitenge/Documents/Doctoral/PhD 2021/Data"

*** Open Main Database and merge with VL data ***

use "$DATA1/TIER_Final-wide.dta", clear 

merge 1:1 PATIENT using "$DATA1/VLData-VTF_Wide.dta"

drop _merge

save "$DATA1/TIER_Final+VL.dta", replace 

*** Merge with facility attendance ***

use "$DATA1/TIER_Final+VL.dta", clear 

merge 1:1 PATIENT using "$DATA1/AHDeXperienced-fac_attend.dta"

drop _merge

save "$DATA1/TIER_Final+VL+Attendance.dta", replace

*** Merge Immunological Data ***

use "$DATA1/TIER_Final+VL+Attendance.dta", clear 

merge 1:1 PATIENT using "$DATA1/TIER_Final+ImmuneRecovery.dta", force 

drop _merge

**** Merge with ART Table ****


merge 1:1 PATIENT using "$DATA1\ART.dta"


drop _merge
count 

*** Save Final Data ****

use "$DATA1/FinalData1.dta", clear

merge 1:1 PATIENT using "$DATA1\DEM.dta"

keep if _merge==3
drop _merge

//drop if Facility==""
count 

save "$DATA1/FinalData.dta", replace







