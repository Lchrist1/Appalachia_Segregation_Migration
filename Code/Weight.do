*******************************************************************************
********************************************************************************
********************************************************************************


*        Advanced Econometrics Term Project: Propensity Score Weights
*                              L. Cedric Christensen 


*-----------------------------------
*Purpose: Create an inverse propensity score weight for the Life-M sample.
*-----------------------------------
*-----------------------------------
*Inputs: 

*IPUMS:
*     NorthCarolina_IPUMS.dta
*     Ohio_IPUMS.dta
*Final Data: 
* 	  Sample.dta
*-----------------------------------
*-----------------------------------
*Notes: 
	
*-----------------------------------
*-----------------------------------
*Table of Contents:

*-----------------------------------
********************************************************************************
********************************************************************************
*******************************************************************************/

*-------------------------------------------------------------------------------
*Section 0: Directory Configuration
*-------------------------------------------------------------------------------

clear
clear frames
set more off
capture log close

use "Private_Data/Ohio_IPUMS.dta", clear

drop if year != 1940

append using "Private_Data/NorthCarolina_IPUMS.dta"


gen county_fips = countyicp
replace county_fips = county_fips/10 if county_fips>999
gen str3 string_county_fips = string(county_fips, "%03.0f")
gen str3 string_state_fips = string(statefip, "%02.0f")
egen fips=concat(string_state_fips string_county_fips)

merge m:1 fips using "Public_Data/AppalachianCounties.dta"

drop if _merge == 2
gen County_App = 0
replace County_App = 1 if _merge == 3
drop _merge 

gen farmstatus = 1
replace farmstatus = 0 if farm != 2

gen own_1 = 0
replace own_1 = 1 if ownershp == 1

gen black = "NotBlack"
replace black = "Black" if race == 2


gen black_num = 0
replace black_num = 1 if black == "Black"

gen native_nc = 0
replace native_nc = 1 if bpl == 37

gen secondgen_nc = 0 
replace secondgen_nc = 1 if mbpl == 37 | fbpl == 37

gen native_oh = 0
replace native_oh = 1 if bpl == 39

gen secondgen_oh = 0 
replace secondgen_oh = 1 if mbpl == 39 | fbpl == 39

gen rural = 0
replace rural = 1 if urban == 1

estpost tabstat black_num County_App sei farmstatus rural sei age  ///
own_1 sex native_nc native_oh secondgen_nc secondgen_oh

merge 1:1 histid using "Clean_Data/Sample.dta"

mvencode InSample, mv(0)
drop _merge


logit InSample own_1 farmstatus i.black_num native_nc secondgen_nc native_oh i.sex secondgen_oh c.age c.sei i.county_fips

predict w_InSample, pr
preserve

gen sample_pweight = 1/w_InSample
replace sample_pweight=1/(1-w_InSample) if InSample==0

sum w_InSample
sum sample_pweight

keep if InSample == 1

keep histid sample_pweight

save "Clean_Data/sampling_pweights.dta", replace
