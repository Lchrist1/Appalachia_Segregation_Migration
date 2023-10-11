/*******************************************************************************
********************************************************************************
********************************************************************************


*                Segregation and Migration in Appalachia: Analysis
*                              L. Cedric Christensen 


*-----------------------------------
*Purpose: Develop summary and analytical statistics for the data cleaned in 
	Christensen_Term_Cleaning.do using 3 way interactions and matching models.
*-----------------------------------
*-----------------------------------
*Input: Clean_Data/Data_Final.dta

*Outputs:
	  
*-----------------------------------
*-----------------------------------
*Notes: 
	
*-----------------------------------
*-----------------------------------
*Table of Contents:
* Section 0.0: Directory Configuration
* Section 1.0: Tables
	*Section 1.1 Table 1
	*Section 1.2 Table 2 (Correlations)
	*Section 1.3 Table 3 (Means Comparison)
	*Section 1.4 Summary Statistics
* Section 2.0: Figures
	*Section 2.1 Histograms for segregation by Appalachia and Race
	*Section 2.1 Histograms for SEI by Appalachia and Race
*Section 3: Regressions
	*Section 3.1 Non-Segregation Race and Region Estimates
	*Section 3.2 Race and Segregation Regressions
	*Section 3.3 Race, Segrgation and Region Regressions
*Section 4: Matching
	*Section 4.1: Developing 'treatment' Category
*Section 5: Exploratory Analysis	
*-----------------------------------
********************************************************************************
********************************************************************************
*******************************************************************************/

clear
clear frames
set more off
capture log close

cd "/Users/lced/Documents/GitHub/Appalachia_Segreagation_Migration"

//log using "Logs/Christensen_Term_Analysis_log.smcl", replace

frame create base
frame change base

use "Data/Clean/Final.dta"
*-------------------------------------------------------------------------------
*Section 1: Summary Tables and Descriptive Statistics
*-------------------------------------------------------------------------------
*---------------------------------------
*Section 1.1 Table 1 (Descriptive Statistics/Balance Test)
*---------------------------------------
eststo clear

estpost tabstat migrant black Last_County_App last_sei yearbirth ///
last_rural last_owner last_farm sex native_nc native_oh secondgen_nc ///
secondgen_oh, ///
 statistics( mean) columns(statistics)
 
esttab using "Output/Tables/Means_table.tex", ///
 title("Table 1: Means by Race and Region") cells("mean") mtitle("Life-M Unweighted") replace

*---------------------------------------
*Section 1.2 Table 2 (Correlations)
*---------------------------------------
mean migrant [pweight = sample_pweight], over(black Last_County_App)
 
pwcorr black Last_County_App last_rural sex native_nc native_oh ///
secondgen_nc secondgen_oh alpha_pb1940

*---------------------------------------
*Section 1.3 Table 3 (Means Comparison)
*---------------------------------------
eststo clear
tabulate black Last_County_App, summarize(migrant) nostandard noobs

*---------------------------------------
*Section 1.4: Other Summary Statistics 
*---------------------------------------
mean blk_total if last_state == 37 [pweight = sample_pweight], over(Last_County_App)

mean alpha_pb1940 if last_state == 37 [pweight = sample_pweight], over(Last_County_App)

*------------------------------------------------------------------------------
*Section 2: Visuals
*------------------------------------------------------------------------------
*---------------------------------------
*Section 2.1: Histograms for segregation by Appalachia and Race
*---------------------------------------
*truncate variables to be between 0 and 1 (use of random sorting as benchmark led to small exceptions)
replace alpha_pb1940 = 0.99999 if alpha_pb1940>1 
replace alpha_pb1940 = 0 if alpha_pb1940<0

histogram alpha_pb1940, bin(9) start(0) by(Last_County_App)
save "Output/Figures/Segregation_by_Appalachia.svg", replace
histogram alpha_pb1940, bin(9) start(0) by(black)
save "Output/Figures/Segregation_by_Black.svg", replace

histogram dissimilarity_pb1940, bin(9) start(0) by(Last_County_App)
save "Output/Figures/Dissimilarity_by_Appalachia.svg", replace
histogram dissimilarity_pb1940, bin(9) start(0) by(black)
save "Output/Figures/Dissimilarity_by_Black.svg", replace

histogram isolation_all1940, bin(9) start(0) by(Last_County_App)
save "Output/Figures/Dissimilarity_by_Appalachia.svg", replace
histogram isolation_all1940, bin(9) start(0) by(black)
save "Output/Figures/Dissimilarity_by_Black.svg", replace
*---------------------------------------
*Section 2.1: Histograms for SEI by Appalachia and Race
*---------------------------------------
hist last_sei  if last_sei !=0, bin(10) by(Last_County_App)
save "Output/Figures/Segregation_by_Black.svg", replace
hist last_sei  if last_sei !=0, bin(10) by(black)


*------------------------------------------------------------------------------
*Section 3: Regressions
*------------------------------------------------------------------------------
*---------------------------------------
*Section 3.1: Non-Segregation Race and Region Estimates
*---------------------------------------
gen blackapp = black*Last_County_App
 gen black_notapp = black
 replace black_notapp = 0 if Last_County_App == 1
 gen whiteapp = Last_County_App
 replace whiteapp = 0 if black == 1

*Interaction Form
reg migrant black##Last_County_App last_rural last_owner pct_black1940 c.last_sei ///
 last_farm sex native_nc i.native_oh i.secondgen_nc i.secondgen_oh  ///
 i.last_state i.blk_total [pweight = sample_pweight], vce(cluster fips)
 
*Binary form (for coef plot)
reg migrant whiteapp black_notapp blackapp last_rural pct_black1940 last_owner c.last_sei ///
 last_farm sex native_nc i.native_oh i.secondgen_nc i.secondgen_oh  ///
 i.last_state i.blk_total [pweight = sample_pweight], vce(cluster fips)

est store migration_estimate_full

reg migrant whiteapp black_notapp blackapp ///
 [pweight = sample_pweight], vce(cluster fips)

 est store migration_estimate_naive
 
esttab migration_estimate_naive migration_estimate_full ///
 using "Output/Tables/BaselineOutput.tex", ///
 mlabels("Logan-Parman Index" "Isolation Index" "Dissimilarity Index") ///
 title("Migration Rates Conditioned on Observables") cells("b(fmt(3))" ///
 "p(fmt(3))") noomitted nobaselevels replace


coefplot migration_estimate, keep(whiteapp black_notapp blackapp last_owner sex native_nc) /// 
 vertical yline(0) xlabel(, ang(45))
save "Output/Figures/BaselineCoeffPlot.svg", replace
*---------------------------------------
*Section 3.2: Race and Segregation Regressions
*---------------------------------------
reg migrant black##c.alpha_pb1940  Last_County_App last_sei yearbirth pct_black1940 ///
last_rural last_owner last_farm sex native_nc native_oh secondgen_nc blk_total ///
secondgen_oh i.last_state [pweight = sample_pweight], vce(cluster fips)
est store RS_Alpha

reg migrant black##c.dissimilarity_pb1940 Last_County_App last_sei pct_black1940 yearbirth ///
last_rural last_owner last_farm sex native_nc native_oh secondgen_nc blk_total ///
secondgen_oh last_state [pweight = sample_pweight], vce(cluster fips)
est store RS_disim

reg migrant black##c.isolation_all1940 Last_County_App last_sei yearbirth pct_black1940 ///
last_rural last_owner last_farm sex native_nc native_oh secondgen_nc i.blk_total ///
secondgen_oh last_state [pweight = sample_pweight], vce(cluster fips)
est store RS_isola

coefplot RS_Alpha RS_disim RS_isola,  drop( Last_County_App last_sei yearbirth ///
i.last_rural last_owner last_farm last_rural sex native_nc native_oh ///
 secondgen_nc blk_total secondgen_oh *last_state _cons black pct_black1940 *.blk_total) ///
 vertical yline(0) xlabel(, ang(45))

 
esttab RS_Alpha RS_isola RS_disim ///
 using "Output/Tables/RacebySegregation.tex", ///
 mlabels("Logan-Parman Index" "Isolation Index" "Dissimilarity Index") ///
 title("Migration Rates Conditioned on Observables") cells("b(fmt(3))" ///
 "p(fmt(3))") noomitted nobaselevels replace
 
*---------------------------------------
*Section 3.3: Race, Segrgation and Region Regressions
*---------------------------------------
 reg migrant black##c.alpha_pb1940##Last_County_App c.last_sei c.yearbirth pct_black1940 ///
last_rural last_owner last_farm sex native_nc native_oh secondgen_nc i.blk_total ///
secondgen_oh last_state [pweight = sample_pweight], vce(cluster fips)

estat ic 
est store fullmodel_alpha

reg migrant black##c.isolation_all1940##Last_County_App last_sei c.yearbirth pct_black1940 ///
last_rural last_owner last_farm sex native_nc native_oh secondgen_nc i.blk_total ///
secondgen_oh last_state [pweight = sample_pweight], vce(cluster fips)

estat ic 
est store fullmodel_isolation

reg migrant black##c.dissimilarity_pb1940##Last_County_App last_sei c.yearbirth  pct_black1940 ///
last_rural last_owner last_farm sex native_nc native_oh secondgen_nc i.blk_total ///
secondgen_oh last_state [pweight = sample_pweight], vce(cluster fips)

estat ic 
est store fullmodel_dissim

coefplot fullmodel_alpha fullmodel_dissim fullmodel_isolation, ///
 drop(last_sei yearbirth last_rural last_owner last_farm last_rural sex  ///
 native_nc native_oh secondgen_nc blk_total secondgen_oh last_state ///
 _cons *.blk_total *black *Last_County_App *black#Last_County_App *Last_County_App#black ///
 isolation_all1940 dissimilarity_pb1940 ///
 alpha_pb1940 *Last_County_App#isolation_all1940 dissimilarity_pb1940#1.Last_County_App alpha_pb1940#Last_County_App) ///
 vertical yline(0) 
 
esttab fullmodel_alpha fullmodel_isolation fullmodel_dissim ///
 using "Output/Tables/Main_Output.tex", ///
 mlabels("Logan-Parman Index" "Isolation Index" "Dissimilarity Index") ///
 title("Main Results") cells("b(fmt(3))" "p(fmt(3))") noomitted nobaselevels replace


*-------------------------------------------------------------------------------
*Section 4: Matching
*-------------------------------------------------------------------------------
*---------------------------------------
*Section 4.1: Developing 'treatment' Category
*---------------------------------------
sum dissimilarity_pb1940, detail
gen dissim_high = 0
replace dissim_high = 1 if dissimilarity_pb1940>.767

sum alpha_pb1940, detail
gen alpha_high = 0 
replace alpha_high = 1 if alpha_pb1940>0.534

sum isolation_all1940, detail
gen isolation_high = 0 
replace isolation_high = 1 if isolation_all1940>0.257

frame copy base black_only
frame change black_only

drop if black != 1

probit dissim_high c.last_sei c.yearbirth i.last_rural i.last_owner i.last_farm ///
i.sex i.native_nc i.native_oh i.secondgen_nc i.secondgen_oh i.last_state ///
pct_black1940 if Last_County_App == 0

predict pr_high_seg_not_Appalachia, pr
hist pr_high_seg_not_Appalachia, by(dissim_high) bin(10)
save "Output/Figures/PrDissim_NotAppalachia.svg", replace

probit dissim_high c.last_sei c.yearbirth i.last_rural i.last_owner i.last_farm ///
 i.sex i.native_nc i.native_oh i.secondgen_nc i.secondgen_oh i.last_state ///
 if Last_County_App == 1

predict pr_high_seg_Appalachia, pr
hist pr_high_seg_Appalachia, by(dissim_high) bin(10)
save "Output/Figures/PrDissim_Appalachia.svg", replace

probit alpha_high c.last_sei c.yearbirth i.last_rural i.last_owner i.last_farm ///
 i.sex i.native_nc i.native_oh i.secondgen_nc i.secondgen_oh i.last_state ///
 if Last_County_App == 0

predict pr_alpha_seg_not_Appalachia, pr
hist pr_alpha_seg_not_Appalachia, by(alpha_high) bin(10)
save "Output/Figures/PrAlpha_NotAppalachia.svg", replace

probit alpha_high c.last_sei c.yearbirth i.last_rural i.last_owner i.last_farm ///
i.sex i.native_nc i.native_oh i.secondgen_nc i.secondgen_oh i.last_state ///
if Last_County_App == 1

predict pr_alpha_seg_Appalachia, pr
hist pr_alpha_seg_Appalachia, by(alpha_high) bin(10)
save "Output/Figures/PrAlpha_Appalachia.svg", replace


probit isolation_high c.last_sei c.yearbirth i.last_rural i.last_owner ///
i.last_farm i.sex i.native_nc i.native_oh i.secondgen_nc i.secondgen_oh ///
i.last_state if Last_County_App == 0

predict pr_isolation_seg_not_Appalachia, pr
hist pr_isolation_seg_not_Appalachia, by(isolation_high) bin(10)
save "Output/Figures/PrIsolation_NotAppalachia.svg", replace

probit isolation_high c.last_sei c.yearbirth i.last_rural i.last_owner ///
i.last_farm i.sex i.native_nc i.native_oh i.secondgen_nc i.secondgen_oh ///
i.last_state if Last_County_App == 1

predict pr_isolation_seg_Appalachia, pr
hist pr_isolation_seg_Appalachia, by(isolation_high) bin(10)
save "Output/Figures/PrIsolation_Appalachia.svg", replace


by Last_County_App, sort : teffects psmatch (migrant) (dissim_high  pct_black1940 ///
 c.last_sei c.yearbirth i.last_rural i.last_owner i.last_farm i.sex i.native_nc ///
 i.native_oh i.secondgen_oh), atet caliper(.5) vce(robust) 
 est store matching_dissim
 
teffects psmatch (migrant) (dissim_high  pct_black1940 ///
c.last_sei c.yearbirth i.last_rural i.last_owner i.last_farm i.sex i.native_nc ///
i.native_oh i.secondgen_oh) if Last_County_App==1, atet caliper(.5) vce(robust)

by Last_County_App, sort : teffects psmatch (migrant) (alpha_high  pct_black1940 ///
 c.last_sei c.yearbirth i.last_rural i.last_owner i.last_farm i.sex i.native_nc ///
 i.native_oh i.secondgen_oh), atet caliper(.1) vce(robust) 
est store matching_alpha

by Last_County_App, sort : teffects psmatch (migrant) (isolation_high pct_black1940 ///
 c.last_sei c.yearbirth i.last_rural i.last_owner i.last_farm i.sex i.native_nc ///
 i.native_oh i.secondgen_oh), atet caliper(.1)  vce(robust)
est store matching_isolation


teffects psmatch (migrant) (dissim_high  pct_black1940 ///
 c.last_sei c.yearbirth i.last_rural i.last_owner i.last_farm i.sex i.native_nc ///
 i.native_oh i.secondgen_oh), atet caliper(.5) vce(robust)

teffects psmatch (migrant) (alpha_high  pct_black1940 ///
 c.last_sei c.yearbirth i.last_rural i.last_owner i.last_farm i.sex i.native_nc ///
 i.native_oh i.secondgen_oh), atet caliper(.1) vce(robust) 

teffects psmatch (migrant) (isolation_high pct_black1940 ///
 c.last_sei c.yearbirth i.last_rural i.last_owner i.last_farm i.sex i.native_nc ///
 i.native_oh i.secondgen_oh), atet caliper(.1)  vce(robust)


*------------------------------------------------------------------------------
*Section 5: Exploratory Analysis
*-------------------------------------------------------------------------------
reg migrant black##c.dissimilarity_pb1940##Last_County_App black##c.alpha_pb1940##Last_County_App  ///
 last_sei c.yearbirth last_rural last_owner last_farm sex native_nc native_oh  ///
 secondgen_nc i.blk_total secondgen_oh last_state [pweight = sample_pweight], vce(cluster fips)

 coefplot, ///
 drop(last_sei yearbirth last_rural last_owner last_farm last_rural sex  ///
 native_nc native_oh secondgen_nc blk_total secondgen_oh last_state ///
 _cons *.blk_total *black *Last_County_App *black#Last_County_App *Last_County_App#black ///
 isolation_all1940 dissimilarity_pb1940 ///
 alpha_pb1940 *Last_County_App#isolation_all1940 dissimilarity_pb1940#1.Last_County_App alpha_pb1940#Last_County_App) ///
 vertical yline(0)
 
logit migrant black##c.dissimilarity_pb1940##Last_County_App black##c.alpha_pb1940##Last_County_App  ///
 last_sei c.yearbirth last_rural last_owner last_farm sex native_nc native_oh  ///
 secondgen_nc i.blk_total secondgen_oh last_state [pweight = sample_pweight], vce(cluster fips)

probit migrant black##c.dissimilarity_pb1940##Last_County_App black##c.alpha_pb1940##Last_County_App  ///
 last_sei c.yearbirth last_rural last_owner last_farm sex native_nc native_oh  ///
 secondgen_nc i.blk_total secondgen_oh last_state [pweight = sample_pweight], vce(cluster fips)
 
 reg migrant black##c.alpha_pb1940 black##c.dissimilarity_pb1940  Last_County_App last_sei yearbirth ///
last_rural last_owner last_farm sex native_nc native_oh secondgen_nc blk_total ///
secondgen_oh i.last_state [pweight = sample_pweight], vce(cluster fips)


coefplot, ///
 drop(last_sei yearbirth last_rural last_owner last_farm last_rural sex  ///
 native_nc native_oh secondgen_nc blk_total secondgen_oh last_state ///
 _cons *.blk_total black Last_County_App *last_state) ///
 vertical yline(0)
 
 
