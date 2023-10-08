*******************************************************************************
********************************************************************************
********************************************************************************


*              Segregation and Migration in Appalachia: Data Cleaning
*                              L. Cedric Christensen 


*-----------------------------------
*Purpose: Intake key raw datasets from IPUMS, Life-M, Logan-Parman, and HAL
*		  dataset; merges the key datasets; and outputs analysis ready data.
*-----------------------------------
*-----------------------------------
*Inputs: 

*IPUMS:
*     NorthCarolina_IPUMS.dta
*     Ohio_IPUMS.dta
*Life-M:
*     lifem_ipums.dta
*     lifem_location.dta
*     lifem_master.dta
*HAL:
*     Racial Violence/HAL.XLS
*Logan-Parman:
*     segregation-data-1880-and-1940.dta
*Appalachian Regional Commission:
*     Appalachian-Counties-Served-by-ARC_2021.xlsx

*Outputs:
*	  $root/Final.dta
*-----------------------------------
*-----------------------------------
*Notes: 
	
*-----------------------------------
*-----------------------------------
*Table of Contents:
*Section 0.0: Directory 
*Section 1.0: Merging Data Prep
	*Section 1.1 Appalachian Counties
	*Section 1.2 Segregation Index
	*Section 1.3 Racial Violence Data
*Section 2.0: Cleaning Census Data
	*Section 2.1 Merging Census records and lifem
	*Section 2.2 Identifying Migrants
	*Section 2.3 Variable Generation
	*Section 2.4 Standardizing Fips and ICPSR County Codes
*Section 3.0: Matching Census Data to Supplemental Data

*-----------------------------------
********************************************************************************
********************************************************************************
*******************************************************************************/

*-------------------------------------------------------------------------------
*Section 0.0: Directory Configuration
*-------------------------------------------------------------------------------

clear
clear frames
set more off
capture log close

log using "Logs/Christensen_TermCleaning_log.smcl", replace
*-------------------------------------------------------------------------------
*Section 1.0: Merging Data Prep
*-------------------------------------------------------------------------------
*---------------------------------------
*Section 1.1 Appalachian Counties

*this section ensures converts the xlsx format to .dta and standardizes fips formatting

*---------------------------------------

frame create AppCounties
frame change AppCounties

import excel "Data/Raw/Appalachian-Counties-Served-by-ARC_2021.xlsx", sheet("ARC Counties") cellrange(A5:C428) firstrow clear

destring FIPS, replace 
gen fips = string(FIPS, "%05.0f")
save "$Data/Intermediate/AppalachianCounties.dta", replace

*---------------------------------------
*Section 1.2 Segregation Index

*this section collects only NC and OH data and standardizes icpsr formatting

*---------------------------------------

frame create segregation
frame change segregation

use "$Data/Public/segregation-data-1880-and-1940.dta", clear

drop if statefip != 37 & statefip != 39

replace stateicpsr = 47 if statefip == 37
replace stateicpsr = 24 if statefip == 39

gen str3 string_county_ICPSR = string(county, "%03.0f")
gen str3 string_state_ICPSR = string(stateicpsr, "%02.0f")
egen icpsr=concat(string_state_ICPSR string_county_ICPSR) 

keep alpha_pb alpha_po dissimilarity_pb dissimilarity_po isolation_all ///
  icpsr year pct_black

duplicates drop

reshape wide alpha_pb alpha_po dissimilarity_pb dissimilarity_po isolation_all pct_black, i(icpsr) j(year)

gen alpha_po_diff =alpha_po1940-alpha_po1880

save "$Data/Intermediate/Segreation_wide.dta", replace

*---------------------------------------
*Section 1.3 Racial Violence Data

*this section imports HAL Racial Violence data, convers county names to fips codes,
* and addresses a few errata

*---------------------------------------


frame create hal 
frame change hal

import excel "$Data/Raw/HAL.XLS", ///
sheet("VICTIMS") cellrange(A1:O2807) firstrow clear

tab Year

drop if Year == "1900s"

destring Year, replace
drop Mo Da Offense Note ndName rdName N Comments Sex Mob Victim

gen lynch = 1
gen race = .
replace race = 0 if Race == "Blk"
replace race = 1 if Race == "Wht"
drop if race == .

collapse (sum) race (sum) lynch, by(State Year County)

gen blk = lynch-race
 

rename State sab
gen cname = strtrim(lower(County))

*errata
drop if cname == "undetermined"
drop if cname == "indeterminant"
keep if sab == "NC"

replace cname= "northampton" if cname == "northamption"
replace cname= "sampson" if cname == "samson"

*Match counties to fips
merge m:1 sab cname using "Data/Raw/countyfipstool20190120-1.dta"

keep if _merge==3

drop _merge

gen fips_1 =string(fips)
drop fips
rename fips_1 fips

keep Year race lynch blk fips

*Generate Decade from Years
gen decade = 80 if 1879<Year<1890
replace decade = 90 if 1889<Year & Year<1900
replace decade = 00 if 1899<Year & Year<1910
replace decade = 10 if 1909<Year & Year<1920
replace decade = 20 if 1919<Year & Year<1930
replace decade = 30 if 1919<Year & Year<1931

drop Year

collapse (sum) race lynch blk, by(fips decade)

reshape wide race lynch blk, i(fips) j(decade)

mvencode race0 lynch0 blk0 race10 lynch10 blk10 race30 lynch30 ///
 blk30 race80 lynch80 blk80 race90 lynch90 blk90, mv(0) override
 
gen blk_total = blk0+blk10+blk30+blk80+blk90
 
save "$Data/Intermediate/RacialViolence_Cleaned_Wide.dta", replace

*-------------------------------------------------------------------------------
*Section 2.0: Cleaning Census Data
*-------------------------------------------------------------------------------
*--------------------------------------
*Section 2.1 Merging Census records and lifem

*Import Census Data and Match to Life-M Vital Record Links, establish basic variables 
*--------------------------------------
frame create Lifem
frame change Lifem
use "Data/Raw/All_LifeM.dta", clear

rename histid histid80
merge 1:m histid80 using "Private_Data/lifem_ipums.dta",  keepusing(lifemid) generate(mlife_80_)
rename lifemid lifemid_80
rename histid80 histid00
drop if mlife_80_ == 2
merge 1:m histid00 using "Private_Data/lifem_ipums.dta", gen(MLIFE_1900) keepusing(lifemid)
drop if MLIFE_1900 == 2
rename histid00 histid10
rename lifemid lifemid_00
merge 1:m histid10 using "Private_Data/lifem_ipums.dta", gen(MLIFE_1910) keepusing(lifemid)
drop if MLIFE_1910 == 2
rename lifemid lifemid_10
rename histid10 histid20
merge 1:m histid20 using "Private_Data/lifem_ipums.dta", gen(MLIFE_1920) keepusing(lifemid)
drop if MLIFE_1920 == 2
rename lifemid lifemid_20
rename histid20 histid40
merge 1:m histid40 using "Private_Data/lifem_ipums.dta", gen(MLIFE_1940) keepusing(lifemid)
drop if MLIFE_1940 == 2
rename histid40 histid
rename lifemid lifemid_40

gen lifemid = lifemid_80 
replace lifemid = lifemid_00 if lifemid ==""
replace lifemid = lifemid_10 if lifemid ==""
replace lifemid = lifemid_20 if lifemid ==""
replace lifemid = lifemid_40 if lifemid ==""

count if lifemid == ""

gen nolink = 0
replace nolink = 1 if  lifemid == ""

merge m:1 lifemid using "Private_Data/lifem_master.dta"
drop if _merge == 2
drop _merge

drop if nolink == 1

gen household = 1
gen rural = 0 
replace rural = 1 if urban == 1

gen farmstatus = 1
replace farmstatus = 0 if farm != 2

gen own_1 = 0
replace own_1 = 1 if ownershp == 1

gen black = "NotBlack"
replace black = "Black" if race == 2

gen native_nc = 0
replace native_nc = 1 if bpl == 37

gen secondgen_nc = 0 
replace secondgen_nc = 1 if mbpl == 37 | fbpl == 37

gen native_oh = 0
replace native_oh = 1 if bpl == 39

gen secondgen_oh = 0 
replace secondgen_oh = 1 if mbpl == 39 | fbpl == 39

keep stateicp statefip countyicp labforce occ1950 ind1950 lnklifem rural ///
 farmstatus own_1 black native_nc secondgen_nc native_oh secondgen_oh lifemid ///
 year sex marst sei histid

reshape wide stateicp statefip countyicp sex marst labforce occ1950 ind1950 ///
 lnklifem rural farmstatus own_1 black native_nc secondgen_nc native_oh ///
 secondgen_oh sei histid, i(lifemid) j(year)

merge m:1 lifemid using "$Data/Raw/lifem_location_wide.dta"
drop if _merge == 2
drop _merge

*--------------------------------------
*Section 2.2 Identifying Migrants

*If missing death record, infer that this person died outside North Carolina
*--------------------------------------


drop if yeardeath<1940
drop if yearbirth>1900

gen migrant = 0
replace migrant = 1 if countyicpdeath == 9993

*---------------------------------------
*Section 2.3: Variable Generation

*Creating one variable for time-consistent factors repeated in multiple census readings

*---------------------------------------

order lifemid-countyicpmrg4 , alpha

gen black = 0
replace black = 1 if black1880 == "Black" | black1900 == "Black" | black1910 == "Black" ///
| black1920 == "Black" | black1940 == "Black"

drop black1880-black1940

gen secondgen_nc = 0
replace secondgen_nc = 1 if secondgen_nc1880 == 1 | secondgen_nc1900 == 1 | ///
 secondgen_nc1910 == 1 | secondgen_nc1920 ==  1 | secondgen_nc1940 == 1 

drop secondgen_nc1880-secondgen_nc1940

gen native_nc = 0
replace native_nc = 1 if native_nc1880 == 1 | native_nc1900 == 1 | ///
 native_nc1910 == 1 | native_nc1920 ==  1 | native_nc1940 == 1 

drop native_nc1880-native_nc1940

gen secondgen_oh = 0
replace secondgen_oh = 1 if secondgen_oh1880 == 1 | secondgen_oh1900 == 1 | ///
 secondgen_oh1910 == 1 | secondgen_oh1920 ==  1 | secondgen_oh1940 == 1 

drop secondgen_oh1880-secondgen_oh1940

gen native_oh = 0
replace native_oh = 1 if native_oh1880 == 1 | native_oh1900 == 1 | ///
 native_oh1910 == 1 | native_oh1920 ==  1 | native_oh1940 == 1 

drop native_oh1880-native_oh1940

gen sex = 0
replace sex = 1 if sex1880 == 1 | sex1900 == 1 | ///
 sex1910 == 1 | sex1920 ==  1 | sex1940 == 1 
drop sex1880-sex1940


*First/last year, state, county for pre-death records


gen last_year = string(yearbirth)
replace last_year = "80" if statefipc80 <990
replace last_year = "00" if statefipc00 <990
replace last_year = "10" if statefipc10 <990
replace last_year = "20" if statefipc20 <990
replace last_year = "40" if statefipc40 <990
drop if last_year != "40"

gen last_county = countyicpbirth
replace last_county = countyicpc80 if countyicpc80 <9990  
replace last_county = countyicpc00 if countyicpc00 <9990 
replace last_county = countyicpc10 if countyicpc10 <9990 
replace last_county = countyicpc20 if countyicpc20 <9990 
replace last_county = countyicpc40 if countyicpc40 <9990 

gen last_state = statefipbirth
replace last_state = statefipc80 if statefipc80 <990
replace last_state = statefipc00 if statefipc00 <990
replace last_state = statefipc10 if statefipc10 <990
replace last_state = statefipc20 if statefipc20 <990
replace last_state = statefipc40 if statefipc40 <990

gen last_state_icpsr = 9999
replace last_state_icpsr = stateicp1880 if stateicp1880 <9990
replace last_state_icpsr = stateicp1900 if stateicp1900 <9990
replace last_state_icpsr = stateicp1910 if stateicp1910 <9990
replace last_state_icpsr = stateicp1920 if stateicp1920 <9990
replace last_state_icpsr = stateicp1940 if stateicp1940 <9990

gen first_county = countyicpc40  
replace first_county = countyicpc20 if countyicpc20 <9990  
replace first_county = countyicpc10 if countyicpc10 <9990  
replace first_county = countyicpc00 if countyicpc00 <9990  
replace first_county = countyicpc80 if countyicpc80 <9990  
replace first_county = countyicpbirth if countyicpbirth <9990    

gen first_state = statefipc40  
replace first_state = statefipc20 if statefipc20 <990
replace first_state = statefipc10 if statefipc10 <990 
replace first_state = statefipc00 if statefipc00 <990
replace first_state = statefipc80 if statefipc80 <990 
replace first_state = statefipbirth if statefipbirth <990

gen county_migrant = 0
replace county_migrant = 1 if last_county != countyicpdeath

count if first_state == last_state

count if statefipdeath == last_state & black == 1

drop if last_state != 37 & last_state != 39 //Drop if they migrate out before 1940

drop countyicp1880-countyicpc80 countyicpmrg1-countyicpmrg4 lnklifem1880-lnklifem1940

*Creating one variable for time-inconsistent factors based on last value

gen last_owner = 0
replace last_owner = own_11880 if last_year == "80" 
replace last_owner = own_11900 if last_year == "00" 
replace last_owner = own_11910 if last_year == "10" 
replace last_owner = own_11920 if last_year == "20" 
replace last_owner = own_11940 if last_year == "40" 
drop own_11880-own_11940

gen last_rural = 0
replace last_rural = rural1880 if last_year == "80" 
replace last_rural = rural1900 if last_year == "00" 
replace last_rural = rural1910 if last_year == "10" 
replace last_rural = rural1920 if last_year == "20" 
replace last_rural = rural1940 if last_year == "40" 
drop rural1880-rural1940

gen last_sei = 0
replace last_sei = sei1880 if last_year == "80" 
replace last_sei = sei1900 if last_year == "00" 
replace last_sei = sei1910 if last_year == "10" 
replace last_sei = sei1920 if last_year == "20" 
replace last_sei = sei1940 if last_year == "40" 
drop sei1880-sei1940

gen last_lab = 0
replace last_lab = labforce1880 if last_year == "80" 
replace last_lab = labforce1900 if last_year == "00" 
replace last_lab = labforce1910 if last_year == "10" 
replace last_lab = labforce1920 if last_year == "20" 
replace last_lab = labforce1940 if last_year == "40" 
drop labforce1880-labforce1940

gen last_farm = 0
replace last_farm = farmstatus1880 if last_year == "80" 
replace last_farm = farmstatus1900 if last_year == "00" 
replace last_farm = farmstatus1910 if last_year == "10" 
replace last_farm = farmstatus1920 if last_year == "20" 
replace last_farm = farmstatus1940 if last_year == "40" 
drop farmstatus1880-farmstatus1940

*--------------------------------------
*Section 2.4 Standardizing Fips and ICPSR County Codes
*--------------------------------------

gen lastcounty_fips = last_county
replace lastcounty_fips = lastcounty_fips/10 if lastcounty_fips>999
replace lastcounty_fips = lastcounty_fips/10 if mod(lastcounty_fips, 10)==0
gen str3 string_lastcounty_fips = string(lastcounty_fips, "%03.0f")
gen str3 string_laststate_fips = string(last_state, "%02.0f")
egen fips=concat(string_laststate_fips string_lastcounty_fips)

gen lastcounty_icpsr = last_county
gen str3 string_lastcounty_icpsr = string(lastcounty_icpsr, "%03.0f")
gen str3 string_laststate_icpsr = "47" if last_state == 37
replace string_laststate_icpsr = "24" if last_state == 39
egen icpsr=concat(string_laststate_icpsr string_lastcounty_icpsr)

*-------------------------------------------------------------------------------
*Section 3.0: Matching Census Data to Supplemental Data
*-------------------------------------------------------------------------------
*Appalachian Data for Last_County
merge m:1 fips using "$Data/Intermediate/AppalachianCounties.dta"

drop if _merge == 2
gen Last_County_App = 0
replace Last_County_App = 1 if _merge == 3

drop _merge 

*rename fips Last_fips
*Appalachian Data for Death County
*gen deathcounty_fips = countyicpdeath
*replace deathcounty_fips = countyicpdeath/10 if countyicpdeath>999
*gen str3 string_deathcounty_fips = string(deathcounty_fips, "%03.0f")
*gen str3 string_deathstate_fips = string(statefipdeath, "%02.0f")
*egen fips=concat(string_deathstate_fips string_deathcounty_fips)
*gen Death_County_App = 0
*replace Death_County_App = 1 if _merge == 3
*drop if _merge==2
*drop _merge


*Racial violence for last_county
merge m:1 fips using "$Data/Intermediate/RacialViolence_Cleaned_Wide.dta"

drop if _merge == 2
drop _merge

drop ind19501880-stateicp1940 yearc00-yearmrg4 string_lastcounty_fips ///
string_laststate_fips string_lastcounty_icpsr string_laststate_icpsr

*Segregation for Last_County
merge m:1 icpsr using "Data/Intermediate/Segreation_wide.dta"

destring last_year, replace

mvencode blk_total, mv(0) override

drop histid1880-histid1920

rename histid1940 histid

drop _merge

merge m:1 histid using "Data/Intermediate/sampling_pweights.dta"

drop if _merge == 1

save "Data/Final/Final.dta", replace

frame copy Lifem sampling
frame change sampling

gen InSample = 1

keep histid InSample

drop if histid == "" //Figure this out later

save "Data/Intermediate/Sample.dta", replace


