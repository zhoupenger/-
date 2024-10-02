	
	
* HFT and OMM paper;	
* Table 8;	
* Before estimating this code, "HFT and OMM_Main Code_Tables 2 and 3" code should be runned.	
* As a result of running "HFT and OMM_Main Code_Tables 2 and 3" code, hftomm.Alltrade11intraday2relvol1 file will be created;	
	
	
*2 SLS IV Approach;	
* first we need to identify the event date;	
* we estimate first stage with unstandartize data;	
	
data hftomm.Alltrade11intraday2relvol1IV;	
set hftomm.Alltrade11intraday2relvol1;	
if date >= 20090605 and date =< 20090831 then instrument = 1;	
if 20090525 =< date =< 20090619 then delete; * dropping this period due to changes in the flash crash implementatin timeline;	
if date >= 20091015 then delete; * dropiing post Oct-15 due to the Raj's arrest;	
if instrument = '.' then instrument = 0;	
totalhftdemand = totalhftdemand/1000000;	
totalhftsupply = totalhftsupply/1000000;	
totalhftmain = totalhftmain/1000000;	
run;	
	
	
	
* first stage estimation to obtain the fitter values;	
	
proc glmselect data =  hftomm.Alltrade11intraday2relvol1IV noprint;	
class ticker / param=ref; 	
model totalhftdemand = instrument stockrelative lnoptionvolume realizedvol	
impl_volatility inversemidprice  absdelta vega gamma	
ticker /  selection  =  none  noint; *only stock fixed effects;	
output out= hftomm.FirstStage1 p=preddemand r=r; * file with totalhftdemand fitted value;	
run;	
	
	
proc glmselect data =  hftomm.FirstStage1 noprint;	
class ticker / param=ref; 	
model totalhftsupply = instrument stockrelative lnoptionvolume realizedvol	
impl_volatility inversemidprice  absdelta vega gamma	
ticker /selection = none noint; 	
output out= hftomm.FirstStage2 p=predS r=rS; * file with totalhftdemand and totalhftsupply fitted values;	
run;	
	
	
proc glmselect data =  hftomm.FirstStage2 noprint;	
class ticker / param=ref; 	
model totalhftmain = instrument stockrelative lnoptionvolume realizedvol	
impl_volatility inversemidprice  absdelta vega gamma	
ticker  / selection  =  none  noint;  	
output out= hftomm.FirstStage3 p=predtotal r=rtotal; * file with totalhftdemand, totalhftsupply, and totalhftmain fitted values;	
run;	
	
* sort data;	
	
proc sort data = hftomm.FirstStage3;	
by ticker date;	
run;	
	
	
* standardize variables;	
	
PROC STDIZE DATA = hftomm.FirstStage3 method=ustd OUT = hftomm.FirstStage3std;	
VAR preddemand predS predtotal quoted stockrelative optionspread optionrelative lnoptionvolume impl_volatility absdelta vega gamma 	
inversemidprice totalhftmain spread2 totalhftdemand totalhftnondemand totalhftsupply totalnonhftsupply realizedvol;	
RUN;	
	
	
* demean all the variables;	
	
%demean (hftomm.FirstStage3std, preddemand); 	
%demean (hftomm.FirstStage3std, predS); 	
%demean (hftomm.FirstStage3std, predtotal);	
%demean (hftomm.FirstStage3std, lnoptionvolume); 	
%demean (hftomm.FirstStage3std, quoted); 	
%demean (hftomm.FirstStage3std, stockrelative); 	
%demean (hftomm.FirstStage3std, optionspread); 	
%demean (hftomm.FirstStage3std, optionrelative); 	
%demean (hftomm.FirstStage3std, impl_volatility); 	
%demean (hftomm.FirstStage3std, absdelta); 	
%demean (hftomm.FirstStage3std, vega); 	
%demean (hftomm.FirstStage3std, gamma); 	
%demean (hftomm.FirstStage3std, inversemidprice); 	
%demean (hftomm.FirstStage3std, totalhftmain);	
%demean (hftomm.FirstStage3std, totalvolume);	
%demean (hftomm.FirstStage3std, totalhftdemand);	
%demean (hftomm.FirstStage3std, totalhftnondemand);	
%demean (hftomm.FirstStage3std, totalhftsupply);	
%demean (hftomm.FirstStage3std, totalnonhftsupply);	
%demean (hftomm.FirstStage3std, realizedvol);	
%demean (hftomm.FirstStage3std, spread2);	
	
	
*  Table 8 estimation results;	
* Column (i);	
	
%FirmTimeCluster(hftomm.FirstStage3std, dm1_spread2, dm1_predtotal 	
dm1_stockrelative dm1_lnoptionvolume	
dm1_impl_volatility  dm1_inversemidprice dm1_absdelta dm1_realizedvol dm1_vega dm1_gamma, noint, baseline_model)	
	
proc print data = temp;	
run;	
	
	
* Column (ii);	
	
%FirmTimeCluster(hftomm.FirstStage3std, dm1_spread2, dm1_predS	
dm1_stockrelative dm1_lnoptionvolume dm1_impl_volatility dm1_gamma dm1_inversemidprice dm1_absdelta dm1_realizedvol	
dm1_vega dm1_gamma , noint, baseline_model)	
	
proc print data = temp;	
run;	
	
	
* Column (iii);	
	
%FirmTimeCluster(hftomm.FirstStage3std, dm1_spread2, dm1_preddemand dm1_stockrelative dm1_lnoptionvolume	
dm1_impl_volatility  dm1_inversemidprice dm1_absdelta  dm1_vega dm1_realizedvol dm1_gamma, noint, baseline_model)	
	
proc print data = temp;	
run;	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
