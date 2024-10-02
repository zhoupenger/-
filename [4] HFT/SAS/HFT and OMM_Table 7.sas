* HFT and OMM paper;
* Table 7;
* Before estimating this code, "HFT abd OMM_Tables 5 and 6" code should be runned.
* As a result of running "HFT abd OMM_Tables 5 and 6" code, hftomm.cboefinal file will be produced;


* sort data;

proc sort data = hftomm.cboefinal;
by underlying_symbol quote_date;
run;

* calculaye midprice from crsp data;

data hftomm.Dailycrsp1;
set hftomm.Dailycrsp;
midpricecrsp = (bid + ask)/2;
keep TICKER DATE midpricecrsp prc;
run;

* rename variables for merging;

data hftomm.Dailycrsp1;
set hftomm.Dailycrsp1;
rename TICKER = underlying_symbol;
rename DATE = quote_date;
run;

* sort data for merging;

proc sort data = hftomm.Dailycrsp1;
by underlying_symbol quote_date;
run;

* merge two datasets;

data hftomm.cboefinalmoney;
merge  hftomm.Dailycrsp1 hftomm.cboefinal;
by underlying_symbol quote_date;
run;

* drop missing values;

data hftomm.cboefinalmoney1;
set hftomm.cboefinalmoney;
if expiry = '.' then delete;
if midpricecrsp = '.' then delete;
allopenbuys = cust_open_buys_small + cust_open_buys_medium + cust_open_buys_large; * calculate all open buys position;
run;


* classify moneyness similar to Bondarenko and Muravyev (2023) working paper;

data hftomm.cboefinalmoney2;
set hftomm.cboefinalmoney1;
if midpricecrsp > strike and type = "P" then moneyness = "otm";
if midpricecrsp < strike and type = "C" then moneyness = "otm";
if moneyness = ' ' then moneyness = "itm";
if moneyness = "itm" then delete; * our first analysis is for OTM options only, hence we delete ITM options;
keep underlying_symbol quote_date type allopenbuys;
run;

* sort data;

proc sort data = hftomm.cboefinalmoney2;
by underlying_symbol quote_date type;
run;


proc means data=hftomm.cboefinalmoney2 noprint;
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
if pcr = '.' then pcr = 0.5;
date_new = input(put(quote_date,yymmddn8.),8.); 
run;



* rename columns;

data hftomm.classified6;
set hftomm.cboefinal6;
rename date_new = date;
rename underlying_symbol = ticker;
run;

proc sort data = hftomm.classified6;
by ticker date;
run;

* calculate our informed trading measure;

data hftomm.classified6;
set hftomm.classified6;
absdeviation = abs(PCR - 0.5);
run;

* sort data;

proc sort data = hftomm.classified6;
by ticker date;
run;


data hftomm.classified6lag;
set hftomm.classified6;
by ticker;
lagabsdeviation = ifn(first.ticker, ., lag(absdeviation));
run;

* merge CBOE OTM data with our HFT data;
proc sort data = hftomm.classified6lag;
by ticker date;
run;

* winsorize data;

%winsorise (hftomm.classified6lag, hftomm.classified6lag, lagabsdeviation, 1); 


* we need to merge our cboe data with the main hft data;

proc sort data = hftomm.Alltrade11intraday2relvol1;
by ticker date;
run;

data hftomm.classified7;
merge hftomm.Alltrade11intraday2relvol1 hftomm.classified6lag;
by ticker date;
run;



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



* Table 7, column (i);

%FirmTimeCluster(hftomm.classified9interstd, dm1_spread2, dm1_lagabsdeviation dm1_insider dm1_interaction1 dm1_totalhftdemand
dm1_stockrelative  dm1_realizedvol dm1_lnoptionvolume
dm1_impl_volatility dm1_absdelta dm1_vega dm1_gamma dm1_inversemidprice, noint, baseline_model)

proc print data = temp;
run;




* now, we start the ITM options;


* sort data;

proc sort data = hftomm.cboefinal;
by underlying_symbol quote_date;
run;

* calculaye midprice from crsp data;

data hftomm.Dailycrsp1;
set hftomm.Dailycrsp;
midpricecrsp = (bid + ask)/2;
keep TICKER DATE midpricecrsp prc;
run;

* rename variables for merging;

data hftomm.Dailycrsp1;
set hftomm.Dailycrsp1;
rename TICKER = underlying_symbol;
rename DATE = quote_date;
run;

* sort data for merging;

proc sort data = hftomm.Dailycrsp1;
by underlying_symbol quote_date;
run;

* merge two datasets;

data hftomm.cboefinalmoney;
merge  hftomm.Dailycrsp1 hftomm.cboefinal;
by underlying_symbol quote_date;
run;

* drop missing values;

data hftomm.cboefinalmoney1;
set hftomm.cboefinalmoney;
if expiry = '.' then delete;
if midpricecrsp = '.' then delete;
allopenbuys = cust_open_buys_small + cust_open_buys_medium + cust_open_buys_large; * calculate all open buys position;
run;


* classify moneyness similar to Bondarenko and Muravyev (2023) working paper;

data hftomm.cboefinalmoney2;
set hftomm.cboefinalmoney1;
if midpricecrsp > strike and type = "P" then moneyness = "otm";
if midpricecrsp < strike and type = "C" then moneyness = "otm";
if moneyness = ' ' then moneyness = "itm";
if moneyness = "otm" then delete; * our second analysis is for ITM options only, hence we delete OTM options;
keep underlying_symbol quote_date type allopenbuys;
run;

* sort data;

proc sort data = hftomm.cboefinalmoney2;
by underlying_symbol quote_date type;
run;


proc means data=hftomm.cboefinalmoney2 noprint;
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
if pcr = '.' then pcr = 0.5;
date_new = input(put(quote_date,yymmddn8.),8.); 
run;



* rename columns;

data hftomm.classified6;
set hftomm.cboefinal6;
rename date_new = date;
rename underlying_symbol = ticker;
run;

proc sort data = hftomm.classified6;
by ticker date;
run;

* calculate our informed trading measure;

data hftomm.classified6;
set hftomm.classified6;
absdeviation = abs(PCR - 0.5);
run;

* sort data;

proc sort data = hftomm.classified6;
by ticker date;
run;


data hftomm.classified6lag;
set hftomm.classified6;
by ticker;
lagabsdeviation = ifn(first.ticker, ., lag(absdeviation));
run;

* merge CBOE OTM data with our HFT data;
proc sort data = hftomm.classified6lag;
by ticker date;
run;

* winsorize data;

%winsorise (hftomm.classified6lag, hftomm.classified6lag, lagabsdeviation, 1); 


* we need to merge our cboe data with the main hft data;

proc sort data = hftomm.Alltrade11intraday2relvol1;
by ticker date;
run;

data hftomm.classified7;
merge hftomm.Alltrade11intraday2relvol1 hftomm.classified6lag;
by ticker date;
run;



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



* Table 7, column (ii);

%FirmTimeCluster(hftomm.classified9interstd, dm1_spread2, dm1_lagabsdeviation dm1_insider dm1_interaction1 dm1_totalhftdemand
dm1_stockrelative  dm1_realizedvol dm1_lnoptionvolume
dm1_impl_volatility dm1_absdelta dm1_vega dm1_gamma dm1_inversemidprice, noint, baseline_model)

proc print data = temp;
run;












* now, we estimate columns (iii) and (iv) of Table 7;
* for this test, we need to run "HFT abd OMM_Tables 5 and 6" code first. 
* as a result of this code, there will be file called, hftomm.classified9inter;


*news analysis;
*read the ravenpack data; * there is a seperate code for the ravenpack data. First, run that code;

data hftomm.ravenpackmain2;
set hftomm.ravenpackmain1un;
date_new = input(put(date,yymmddn8.),8.); 
drop date;
run;

* rename variable;

data hftomm.ravenpackmain2;
set hftomm.ravenpackmain2;
rename date_new = date;
rename unit = newsdummy; * each row is one unit as each row captures news;
run;

* we need news dummy, which equals to 1 if there is news;
* hence, we sort the data with nodupkey;

proc sort data = hftomm.ravenpackmain2 nodupkey;
by ticker date;
run;

* this data has already been generated by running "HFT abd OMM_Tables 5 and 6" code;

proc sort data = hftomm.classified9inter;
by ticker date;
run;
data hftomm.ravenpackmain3;
merge hftomm.ravenpackmain2  hftomm.classified9inter;
by ticker date;
run;

data hftomm.ravenpackmain4;
set hftomm.ravenpackmain3;
if lagabsdeviation = '.' then delete;
if newsdummy = ' ' then newsdummy = 0;
run;

* first, only news days;

data hftomm.ravenpackmain4news;
set hftomm.ravenpackmain4;
if newsdummy = 0 then delete;
run;


* standartize it;

PROC STDIZE DATA = hftomm.ravenpackmain4news method=ustd OUT = hftomm.ravenpackmain4news;
VAR lagabsdeviation interaction1 quoted stockrelative optionspread optionrelative lnoptionvolume impl_volatility absdelta vega gamma 
inversemidprice totalhftmain spread2 totalhftdemand totalhftnondemand totalhftsupply totalnonhftsupply realizedvol;
RUN;

* demean all variables for the fixed effects;

%demean (hftomm.ravenpackmain4news, spread2); 
%demean (hftomm.ravenpackmain4news, lagabsdeviation); 
%demean (hftomm.ravenpackmain4news, insider); 
%demean (hftomm.ravenpackmain4news, interaction1); 

%demean (hftomm.ravenpackmain4news, totalhftdemand); 
%demean (hftomm.ravenpackmain4news, totalhftnondemand); 
%demean (hftomm.ravenpackmain4news, stockrelative); 
%demean (hftomm.ravenpackmain4news, realizedvol); 

%demean (hftomm.ravenpackmain4news, lnoptionvolume); 
%demean (hftomm.ravenpackmain4news, impl_volatility); 
%demean (hftomm.ravenpackmain4news, absdelta); 

%demean (hftomm.ravenpackmain4news, vega); 
%demean (hftomm.ravenpackmain4news, gamma); 
%demean (hftomm.ravenpackmain4news, inversemidprice); 


* Table 7, column (iii);

%FirmTimeCluster(hftomm.ravenpackmain4news, dm1_spread2, dm1_lagabsdeviation dm1_insider dm1_interaction1
dm1_totalhftdemand
dm1_stockrelative  dm1_realizedvol dm1_lnoptionvolume
dm1_impl_volatility dm1_absdelta dm1_vega dm1_gamma dm1_inversemidprice, noint, baseline_model)

proc print data = temp;
run;



* now, we repeat the same process for column (iv);
* however, we use no-news days only;

data hftomm.ravenpackmain4nonews;
set hftomm.ravenpackmain4;
if newsdummy = 1 then delete; * delete news days;
run;

* standartize it;

PROC STDIZE DATA = hftomm.ravenpackmain4nonews method=ustd OUT = hftomm.ravenpackmain4nonews;
VAR lagabsdeviation interaction1 quoted stockrelative optionspread optionrelative lnoptionvolume impl_volatility absdelta vega gamma 
inversemidprice totalhftmain spread2 totalhftdemand totalhftnondemand totalhftsupply totalnonhftsupply realizedvol;
RUN;


%demean (hftomm.ravenpackmain4nonews, spread2); 
%demean (hftomm.ravenpackmain4nonews, lagabsdeviation); 
%demean (hftomm.ravenpackmain4nonews, insider); 
%demean (hftomm.ravenpackmain4nonews, interaction1); 

%demean (hftomm.ravenpackmain4nonews, totalhftdemand); 
%demean (hftomm.ravenpackmain4nonews, totalhftnondemand); 
%demean (hftomm.ravenpackmain4nonews, stockrelative); 
%demean (hftomm.ravenpackmain4nonews, realizedvol); 

%demean (hftomm.ravenpackmain4nonews, lnoptionvolume); 
%demean (hftomm.ravenpackmain4nonews, impl_volatility); 
%demean (hftomm.ravenpackmain4nonews, absdelta); 

%demean (hftomm.ravenpackmain4nonews, vega); 
%demean (hftomm.ravenpackmain4nonews, gamma); 
%demean (hftomm.ravenpackmain4nonews, inversemidprice); 

* Table 7, column (iv);

%FirmTimeCluster(hftomm.ravenpackmain4nonews, dm1_spread2, dm1_lagabsdeviation dm1_insider dm1_interaction1
dm1_totalhftdemand
dm1_stockrelative  dm1_realizedvol dm1_lnoptionvolume
dm1_impl_volatility dm1_absdelta dm1_vega dm1_gamma dm1_inversemidprice, noint, baseline_model)

proc print data = temp;
run;





* our next test is a cross-sectional analysis based on trade size;
* Before estimating this code, "HFT abd OMM_Tables 5 and 6" code should be runned.
* As a result of running "HFT abd OMM_Tables 5 and 6" code, hftomm.cboefinal file will be produced;


data hftomm.cboefinal1;
set hftomm.cboefinal;
allopenbuys = cust_open_buys_small; * only small;
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


* estimate Table 7, column (v);

%FirmTimeCluster(hftomm.classified9interstd, dm1_spread2, dm1_lagabsdeviation dm1_insider dm1_interaction1
dm1_totalhftdemand 
dm1_stockrelative  dm1_realizedvol dm1_lnoptionvolume
dm1_impl_volatility dm1_absdelta dm1_vega dm1_gamma dm1_inversemidprice, noint, baseline_model)


proc print data = temp;
run;




* we repeat everything in column (v). The only difference is we now use non-small trade size, which is grouped as large;

data hftomm.cboefinal1;
set hftomm.cboefinal;
allopenbuys = cust_open_buys_medium + cust_open_buys_large; * non-small;
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


* estimate Table 7, column (v);

%FirmTimeCluster(hftomm.classified9interstd, dm1_spread2, dm1_lagabsdeviation dm1_insider dm1_interaction1
dm1_totalhftdemand 
dm1_stockrelative  dm1_realizedvol dm1_lnoptionvolume
dm1_impl_volatility dm1_absdelta dm1_vega dm1_gamma dm1_inversemidprice, noint, baseline_model)


proc print data = temp;
run;
