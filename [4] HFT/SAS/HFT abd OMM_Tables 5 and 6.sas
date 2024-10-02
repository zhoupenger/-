
* HFT and OMM paper;
* Table 5;
* Before estimating this code, "HFT and OMM_Main Code_Tables 2 and 3" code should be runned.
* As a result of running "HFT and OMM_Main Code_Tables 2 and 3" code, hftomm.Alltrade11intraday2relvol1 file will be created;


data hftomm.cboefinal1;
set hftomm.cboefinal;
allopenbuys = cust_open_buys_small + cust_open_buys_medium + cust_open_buys_large; * cust only;
run;



*keep only short-term;

data hftomm.cboefinal2;
set hftomm.cboefinal1;
maturitydate = expiry - quote_date;
if maturitydate >= 180 then delete;
keep underlying_symbol quote_date type allopenbuys;
run;


* sort dataset;

proc sort data = hftomm.cboefinal2;
by underlying_symbol quote_date type;
run;

* daily types;

proc means data=hftomm.cboefinal2 noprint;
class underlying_symbol quote_date type;
var allopenbuys;
output out=hftomm.cboefinal3 (drop = _type_ _freq_) sum = ;
run;

* delete missing values;

data hftomm.cboefinal4;
set hftomm.cboefinal3;
if underlying_symbol = ' ' then delete;
if quote_date = '.' then delete;
if type = ' ' then delete;
run;

proc sort data = hftomm.cboefinal4;
by underlying_symbol quote_date;
run;

* transpose dataset to make it panel;
proc transpose data = hftomm.cboefinal4 out=hftomm.cboefinal5 (drop = _NAME_);
by underlying_symbol quote_date;
id type;
var allopenbuys;
run;


* calculate put-call ratio;
data hftomm.cboefinal6;
set hftomm.cboefinal5;
if C = '.' then C = 0;
if P = '.' then P = 0;
PCR = (P)/((P) + (C));
if pcr = '.' then pcr = 0.5; * if both P and C are zero, then pcr = 0.5;
date_new = input(put(quote_date,yymmddn8.),8.); 
run;




*rename;

data hftomm.classified6;
set hftomm.cboefinal6;
rename date_new = date;
rename underlying_symbol = ticker;
run;

proc sort data = hftomm.classified6;
by ticker date;
run;

* our informed trading measure;

data hftomm.classified6;
set hftomm.classified6;
absdeviation = abs(PCR - 0.5);
run;


* sort dataset;

proc sort data = hftomm.classified6;
by ticker date;
run;


* calculate the lagged value;
data hftomm.classified6lag;
set hftomm.classified6;
by ticker;
lagabsdeviation = ifn(first.ticker, ., lag(absdeviation));
run;

* sort dataset;
proc sort data = hftomm.classified6lag;
by ticker date;
run;

* winsorize it;

%winsorise (hftomm.classified6lag, hftomm.classified6lag, absdeviation, 1); 
%winsorise (hftomm.classified6lag, hftomm.classified6lag, lagabsdeviation, 1);  



* merge CBOE data with the baseline data;

proc sort data = hftomm.classified6lag;
by ticker date;
run;

proc sort data = hftomm.Alltrade11intraday2relvol1;
by ticker date;
run;

data hftomm.classified7;
merge hftomm.classified6lag hftomm.Alltrade11intraday2relvol1;
by ticker date;
run;


* delete missing values;

data hftomm.classified8;
set hftomm.classified7;
if spread2 = '.' then delete;
if lagabsdeviation = '.' then delete;
run;

* sort dataset;

proc sort data = hftomm.classified8;
by ticker date;
run;


data hftomm.classified9;
set hftomm.classified8;
if 20091006 =< date =< 20091015 then delete; * delete days around arrest;
if date < 20090815 then delete; * 2 months before the arrest;
if date > 20091215 then delete; * 2 months after the arrest;
run;


* generate insider dummy;

data hftomm.classified9inter;
set hftomm.classified9;
if date =< 20091015 then insider = 1;
if insider = '.' then insider = 0;
run;



* interaction variables;

data hftomm.classified9inter;
set hftomm.classified9inter;
interaction1 = lagabsdeviation * insider;
interaction2 = insider*totalhftdemand;
run;


* standartize it;

PROC STDIZE DATA = hftomm.classified9inter method=ustd OUT = hftomm.classified9interstd;
VAR lagabsdeviation interaction1 interaction2 quoted stockrelative optionspread optionrelative lnoptionvolume impl_volatility absdelta vega gamma 
inversemidprice totalhftmain spread2 totalhftdemand totalhftnondemand totalhftsupply totalnonhftsupply realizedvol;
RUN;

%demean (hftomm.classified9interstd, lagabsdeviation); 
%demean (hftomm.classified9interstd, insider); 
%demean (hftomm.classified9interstd, interaction1); 
%demean (hftomm.classified9interstd, interaction2); 

%demean (hftomm.classified9interstd, quoted); 
%demean (hftomm.classified9interstd, stockrelative); 
%demean (hftomm.classified9interstd, lnoptionvolume);
%demean (hftomm.classified9interstd, absdelta); 
%demean (hftomm.classified9interstd, impl_volatility); 
%demean (hftomm.classified9interstd, gamma); 
%demean (hftomm.classified9interstd, vega); 
%demean (hftomm.classified9interstd, inversemidprice); 
%demean (hftomm.classified9interstd, realizedvol);
%demean (hftomm.classified9interstd, spread2);
%demean (hftomm.classified9interstd, totalhftdemand);
%demean (hftomm.classified9interstd, totalhftsupply);



* Now we estimate Table 5;
* column (i);

%FirmTimeCluster(hftomm.classified9interstd, dm2_spread2, dm2_lagabsdeviation
dm2_stockrelative  dm2_realizedvol dm2_lnoptionvolume
dm2_impl_volatility dm2_absdelta dm2_vega dm2_gamma dm2_inversemidprice, noint, baseline_model)

proc print data = temp;
run;

* column (ii);
%FirmTimeCluster(hftomm.classified9interstd, dm1_spread2, dm1_lagabsdeviation dm1_insider dm1_interaction1
dm1_stockrelative  dm1_realizedvol dm1_lnoptionvolume
dm1_impl_volatility dm1_absdelta dm1_vega dm1_gamma dm1_inversemidprice, noint, baseline_model)

proc print data = temp;
run;

* column (iii);

%FirmTimeCluster(hftomm.classified9interstd, dm2_totalhftsupply,  dm2_lagabsdeviation
dm2_stockrelative  dm2_realizedvol dm2_lnoptionvolume
dm2_impl_volatility dm2_absdelta dm2_vega dm2_gamma dm2_inversemidprice, noint, baseline_model)

proc print data = temp;
run;

* column (iv);

%FirmTimeCluster(hftomm.classified9interstd, dm1_totalhftsupply, dm1_lagabsdeviation dm1_insider dm1_interaction1
dm1_stockrelative  dm1_realizedvol dm1_lnoptionvolume
dm1_impl_volatility dm1_absdelta dm1_vega dm1_gamma dm1_inversemidprice
, noint, baseline_model)

proc print data = temp;
run;


* column (v);

%FirmTimeCluster(hftomm.classified9interstd, dm2_totalhftdemand, dm2_lagabsdeviation
dm2_stockrelative  dm2_realizedvol dm2_lnoptionvolume
dm2_impl_volatility dm2_absdelta dm2_vega dm2_gamma dm2_inversemidprice , noint, baseline_model)

proc print data = temp;
run;


* column (vi);

%FirmTimeCluster(hftomm.classified9interstd, dm1_totalhftdemand, dm1_lagabsdeviation dm1_insider dm1_interaction1
dm1_stockrelative  dm1_realizedvol dm1_lnoptionvolume
dm1_impl_volatility dm1_absdelta dm1_vega dm1_gamma dm1_inversemidprice
, noint, baseline_model)

proc print data = temp;
run;



* Table 6;

%FirmTimeCluster(hftomm.classified9interstd, dm1_spread2, dm1_lagabsdeviation dm1_insider dm1_interaction1
dm1_totalhftdemand dm1_interaction2
dm1_stockrelative  dm1_realizedvol dm1_lnoptionvolume
dm1_impl_volatility dm1_absdelta dm1_vega dm1_gamma dm1_inversemidprice, noint, baseline_model)

proc print data = temp;
run;


