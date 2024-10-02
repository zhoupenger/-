* HFT and OMM paper;	
* Table 9;	
* Before estimating this code, "HFT and OMM_Table 4" code should be runned.	
* As a result of running "HFT and OMM_Table 4" code, hftomm.totalhigharbitragea file will be created;	
	
	
* generating instrument;	
data hftomm.totalhigharbitrageaIV;	
set hftomm.totalhigharbitragea;	
if date >= 20090605 and date =< 20090831 then instrument = 1;	
if 20090525 =< date =< 20090619 then delete; * dropping this period due to changes in the flash crash implementatin timeline;	
if date >= 20091015 then delete; * dropiing post Oct-15 due to the Raj's arrest;	
if instrument = '.' then instrument = 0;	
totalhftdemand = totalhftdemand/1000000;	
totalhftsupply = totalhftsupply/1000000;	
totalhftmain = totalhftmain/1000000;	
run;	
	
	
* first stage estimation to obtain the fitter values;	
* we use non-standartized data here;	
	
proc glmselect data =  hftomm.totalhigharbitrageaIV noprint;	
class ticker / param=ref; 	
model totalhftdemand = instrument stockrelative lnoptionvolume realizedvol	
impl_volatility inversemidprice  absdelta vega gamma	
ticker /  selection  =  none  noint; *only stock fixed effects;	
output out= hftomm.FirstStage1channel p=pred r=r; * file with totalhftdemand fitted value;	
run;	
	
	
* first stage estimation to obtain the fitter values;	
proc glmselect data =  hftomm.FirstStage1channel noprint;	
class ticker / param=ref; 	
model totalhftmain = instrument stockrelative lnoptionvolume realizedvol	
impl_volatility inversemidprice  absdelta vega gamma	
ticker  / selection  =  none  noint;  	
output out= hftomm.FirstStage3channel p=predtotal r=rtotal; * file with totalhftdemand and totalhftmain fitted values;	
run;	
	
	
* now, we need to merge it with the original dataset;	
	
proc sort data = hftomm.FirstStage3channel;	
by ticker date;	
run;	
proc sort data = hftomm.totalhigharbitrageaIV;	
by ticker date;	
run;	
	
/*add instrument*/	
data hftomm.totalhigharbitrageastdIVf;	
merge hftomm.FirstStage3channel hftomm.totalhigharbitrageaIV;	
by ticker date;	
run;	
	
	
data hftomm.totalhigharbitrageastdIVf1;	
set hftomm.totalhigharbitrageastdIVf;	
if pred = '.' then delete;	
if high = '.' then delete;	
fitinteraction1 = pred*high;	
fitinteraction5 = predtotal*high;	
run;	
	
	
PROC STDIZE DATA = hftomm.totalhigharbitrageastdIVf1 method=mad OUT = hftomm.totalhigharbitrageastdIVf12;	
VAR pred predtotal fitinteraction1  fitinteraction5 quoted stockrelative optionspread optionrelative 	
lnoptionvolume impl_volatility absdelta vega gamma inversemidprice  totalhftmain spread2 totalhftdemand 	
totalhftnondemand totalhftsupply totalnonhftsupply realizedvol;	
RUN;	
	
%demean (hftomm.totalhigharbitrageastdIVf12, pred); 	
%demean (hftomm.totalhigharbitrageastdIVf12, predtotal);	
%demean (hftomm.totalhigharbitrageastdIVf12, high); 	
	
%demean (hftomm.totalhigharbitrageastdIVf12, fitinteraction1); 	
%demean (hftomm.totalhigharbitrageastdIVf12, fitinteraction5);	
 	
%demean (hftomm.totalhigharbitrageastdIVf12, lnoptionvolume); 	
%demean (hftomm.totalhigharbitrageastdIVf12, quoted); 	
%demean (hftomm.totalhigharbitrageastdIVf12, stockrelative); 	
%demean (hftomm.totalhigharbitrageastdIVf12, optionspread); 	
%demean (hftomm.totalhigharbitrageastdIVf12, optionrelative); 	
%demean (hftomm.totalhigharbitrageastdIVf12, impl_volatility); 	
%demean (hftomm.totalhigharbitrageastdIVf12, absdelta); 	
%demean (hftomm.totalhigharbitrageastdIVf12, vega); 	
%demean (hftomm.totalhigharbitrageastdIVf12, gamma); 	
%demean (hftomm.totalhigharbitrageastdIVf12, inversemidprice); 	
%demean (hftomm.totalhigharbitrageastdIVf12, totalhftmain);	
%demean (hftomm.totalhigharbitrageastdIVf12, totalvolume);	
%demean (hftomm.totalhigharbitrageastdIVf12, totalhftdemand);	
%demean (hftomm.totalhigharbitrageastdIVf12, totalhftnondemand);	
%demean (hftomm.totalhigharbitrageastdIVf12, totalhftsupply);	
%demean (hftomm.totalhigharbitrageastdIVf12, totalnonhftsupply);	
%demean (hftomm.totalhigharbitrageastdIVf12, realizedvol);	
%demean (hftomm.totalhigharbitrageastdIVf12, spread2);	
	
	
* Table 9;	
	
*  two-way fixed effect and double clustering using demean; 	
* column (i);	
	
%FirmTimeCluster(hftomm.totalhigharbitrageastdIVf12, dm1_spread2, dm1_predtotal dm1_high	
dm1_fitinteraction5	
dm1_stockrelative  dm1_realizedvol dm1_lnoptionvolume	
dm1_impl_volatility dm1_inversemidprice dm1_absdelta dm1_vega dm1_gamma, noint, baseline_model)	
	
	
* Two way fixed effect results with double-clustered standard errors are generated in temp file;	
	
proc print data = temp;	
run;	
	
	
* column (ii);	
	
%FirmTimeCluster(hftomm.totalhigharbitrageastdIVf12, dm1_spread2, dm1_pred dm1_high	
dm1_fitinteraction1	
dm1_stockrelative  dm1_realizedvol dm1_lnoptionvolume	
dm1_impl_volatility dm1_inversemidprice dm1_absdelta dm1_vega dm1_gamma, noint, baseline_model)	
	
* Two way fixed effect results with double-clustered standard errors are generated in temp file;	
	
proc print data = temp;	
run;	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
