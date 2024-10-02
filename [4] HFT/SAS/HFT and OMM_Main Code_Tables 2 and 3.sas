							
libname hftomm ''; 							
							
* 主要功能函数;							
							
* Mcro for winsorizing variables; 						
%macro winsorise (inds, outds, var, n);							
%let L=&n.;    %* 1th percentile *; %let H=%eval(100 - &L);   %* 99th percentile*;							
proc univariate data = &inds. noprint;							
      * define variables to be winsorised; 							
   var &var.;							
      * define the left (pl) and right tail (ph), output pl-s and ph-s percentile of all variables, and redirect the output to a different file (_winsor); 							
   output out=_winsor   pctlpts=&L  &H  pctlpre=_&var.;							
run;							
data &outds. (drop=_: &var.); set &inds.;							
  if _n_=1 then set _winsor;							
  array wlo  {*} _&var.&L ;							
  array whi  {*} _&var.&H ;							
  array wval {*} w&var.;							
  array val   {*} &var.;							
  do _V=1 to dim(val);							
     wval{_V}=min(max(val{_V},wlo{_V}),whi{_V});							
  end;							
  drop _V;							
run;							
      * rename the winsorised variables back to the original variable names; 							
data &outds.; set &outds.; rename							
 w&var. = &var.;							
run;							
%mend;							
							

   * Two-way fixed effect model with two-way clustered standard errors (Thompson (2011) and eq. 16 of Petersen (2009)); 							
%macro FirmTimeCluster(dataset, DependentVariable, IndependentVariable, noint, ModelName);							
    proc sort data = &dataset; by ticker date; run;							
							
	ods output ParameterEstimates = temp fitstatistics = fit;						
	proc surveyreg data = &dataset ; 						
		cluster ticker; * Cluster by first dimension - firm;					
		model &DependentVariable = &IndependentVariable  / solution &noint. CLPARM; 					
	run; quit;						
							
    ods output ParameterEstimates = temp1;							
	proc surveyreg data = &dataset ; 						
		cluster date; * Cluster by second dimension - year;					
		model &DependentVariable = &IndependentVariable / solution &noint. CLPARM; 					
	run; quit;						
							
    ods output ParameterEstimates = temp2;							
	proc surveyreg data = &dataset ; 						
		cluster ticker date; * Cluster by both dimensions;					
		model &DependentVariable = &IndependentVariable / solution &noint. CLPARM; 					
	run; quit;						
							
    data temp (drop = denDF stderr1 stderr2); 							
		merge temp temp1 (keep = parameter stderr rename=(stderr=stderr1)) temp2 (keep = parameter stderr rename=(stderr=stderr2));					
		where substrn(parameter,1,3) ^= "ticker" & substrn(parameter,1,4) ^= "date";					
		stdErr = sqrt((stdErr**2)+(stdErr1**2)-(stdErr2**2)); 					
		tValue = round(Estimate/stdErr, .01); 					
		probT = 2*(1-probnorm(abs(tValue))); * Assumes large number of observations;					
		format DependentVariable $20. ; 					
		DependentVariable = "&DependentVariable";					
		format ModelName $20. ; 					
		ModelName = "&ModelName";					
	run;						
							
	proc datasets nolist; *append parameter estimates;						
		append base = estimates_2c data = temp force; 					
	run; quit;						
							
							
    data fit; set fit; where Label1 = 'R-Square';							
        format DependentVariable $20. ; 							
		DependentVariable = "&DependentVariable";					
		format ModelName $20. ; 					
		ModelName = "&ModelName";					
	run;						
 							
    proc datasets nolist;  *append fit statistics;							
		append base = fit_2c data = fit force; 					
	run; quit;						
							
%mend FirmTimeCluster;							
							
							
							
   * Macro for de-meaning variable - this macro de-mean variables by firm and firm-time;							
%macro demean (inds, var);							
        *mean by firm;							
proc sort data = &inds.; by ticker; run; 							
proc means data = &inds. noprint; by ticker;							
        output out = byfirm (drop = _type_ _freq_)							
	    mean (&var.) = mbf&var.;						
run; 							
        *mean by time;							
proc sort data = &inds.; by date; run; 							
proc means data = &inds. noprint; by date;							
        output out = bytime (drop = _type_ _freq_)							
	    mean (&var.) = mbt&var.;						
run; 							
        *mean by all sample and save as macro variable;							
proc means data = &inds. noprint; 							
        output out = mall (drop = _type_ _freq_)							
	    mean (&var.) = m&var.;						
run;							
data mall; set mall; call symput('mall', m&var.); run;							
        *merge mbf with with main dataset;							
proc sort data = &inds.; by ticker; run;							
data &inds.; merge &inds. byfirm; by ticker; run;							
        *merge mbt with with main dataset;							
proc sort data = &inds.; by date; run; 							
data &inds.; merge &inds. bytime; by date; run;							
        *call for macro variables for all sample mean;							
data &inds.; set &inds.; m&var. = &mall.; run; 							
        *(i) de-mean only by firm, (ii) de-mean both by firm and time;							
data &inds.; set &inds.; 							
  dm1_&var. = &var. - mbf&var.; *(i);							
  dm2_&var. = &var. - mbf&var. - mbt&var. + m&var.; *(ii);							
  drop mbf&var. mbt&var. m&var.;							
run;							
        *delete datasets everytime by the end of macro;							
proc datasets lib = work nolist; delete byfirm bytime mall; run; quit; 							
%mend;							
							
							
* rank macro;							
							
%macro rank (inds, outds, byvars, N, oldvars, newvars);							
proc sort data = &inds. out=&outds.; by &byvars.; run;							
proc rank data=&outds. out=&outds. groups=&N.; 							
   by &byvars.;							
   var &oldvars.;							
   ranks &newvars.;							
run;  							
  *levels start from 1 rather than 0; 							
data &outds.; set &outds.; &newvars. +1;run;							
%mend;							
							
							
							
*Starting with the HFT data;							
							
data alltrade1;							
set hftomm.nasdaqhft; *original NASDAQ HFT data;							
time2 = time/1000; * converting NASDAQ time to standard time format;							
format time2 time12.3; * time format;							
format date ddmmyy10.; * date format;							
date_new = input(put(date,yymmddn8.),8.); *date re-format;							
drop time date;							
run;							
							
							
							
* computing volume by stock/date/type;							
							
* this code helps us to compute daily volume for HFTs and nonHFTs;							
proc summary data=alltrade1 nway;							
class symbol date_new type;							
var shares;							
output out=alltrade2 (drop = _type_ _freq_) sum=;							
run;							
							
							
* transpose columns;							
proc transpose data=alltrade2 out=alltrade3 (drop=_name_ _LABEL_) prefix=type_;							
by symbol date_new;							
id type;							
var shares;							
run;							
							
* Computing daily buy and sell volume. We use it to compute order imbalance (oib);							
proc summary data=alltrade1 nway;							
class symbol date_new buysell;							
var shares;							
output out=alltrade2oib (drop = _type_ _freq_) sum=;							
run;							
							
* transpose columns;							
							
proc transpose data=alltrade2oib out=alltrade3oib (drop=_name_ _LABEL_) prefix=buysell_;							
by symbol date_new;							
id buysell;							
var shares;							
run;							
							
* sort data;							
							
PROC SORT DATA=alltrade1 OUT=alltrade1;							
BY symbol date_new;							
RUN ;							
							
* last price per stock/day to compute absolute price change;							
* We also calculate return;							
							
data alltradeprice;							
set alltrade1;							
by symbol date_new;							
if last.symbol or last.date_new; * keep last price for each stock/day;							
keep symbol date_new price;							
run;							
							
							
* computing return and volatility;							
data alltradeprice1 (keep = symbol date_new price return volatility); 							
set alltradeprice; 							
by symbol date_new;							
*clean price;							
if price = . then delete; 							
 *calculate return;							
lagprice = ifn(first.symbol, ., lag(price)); *lagged price;							
if lagprice = . then delete; * drop if lagged price is missing;							
volatility = abs(price-lagprice);							
return = 100*(price-lagprice)/lagprice; *daily returns;							
run;							
							
* sort NASDAQ daily data;							
							
PROC SORT DATA=alltrade3 OUT=alltrade3;							
  BY symbol date_new;							
RUN ;							
							
* sort Order imbalance data;							
PROC SORT DATA=alltrade3oib OUT=alltrade3oib;							
  BY symbol date_new;							
RUN ;							
							
* merge volatility, oib and main datasets;							
data alltrade4;							
merge alltrade3 alltrade3oib alltradeprice1;							
by symbol date_new;							
run;							
							
*computing main variables and deleting missing values;							
data hftomm.alltrade5;							
set alltrade4;							
if type_HN = '.' then type_HN = 0; * if there is no HN value then HN = 0;							
if type_HH = '.' then type_HH = 0;							
if type_NH = '.' then type_NH = 0;							
if type_NN = '.' then type_NN = 0;							
if buysell_B = '.' then buysell_B = 0;							
if buysell_S = '.' then buysell_S = 0;							
totalvolume = buysell_B + buysell_S; * total volume computation;							
OIB = abs(buysell_B - buysell_S)/totalvolume; * order imbalance (Chordia, 2002); 							
lnvolume = log(totalvolume); * natural log of volume;							
inverse = 1/price; * inverse price;							
if price = . | volatility = . | totalvolume = .  then delete; 							
totalhftdemand = type_HN + type_HH;							
totalhftnondemand = type_NH + type_NN;							
totalhftsupply = type_NH + type_HH;							
totalnonhftsupply = type_HN + type_NN;							
totalhftmain = type_HN + type_NH + type_HH;							
run;							
							
							
							
* we need to merge HFT data with the bid-ask spread data as we need stock relative spread;							
* this is daily bid-ask spread from CRSP;							
							
data Bidask1;							
 set hftomm.Bidask;							
 quoted = ASK - BID;							
 midquote = (ASK + BID)/2;							
 rspread = quoted/midquote;							
 if rspread < 0 then delete; * drop is spread is less than 0;							
 rename ticker = symbol; * rename variable to match nasdaq variable names;							
 date_new = input(put(date,yymmddn8.),8.); *date re-format;						
run;							
							
* drop variables;							
data Bidask1;							
set Bidask1;							
keep symbol date_new quoted midquote rspread;							
run;							

	
* sort dataset;							
							
PROC SORT DATA=Bidask1;							
  BY symbol date_new;							
RUN ;							
							
							
							
* sort main hft dataset;							
							
PROC SORT DATA=hftomm.alltrade5;							
  BY symbol date_new;							
RUN ;							
							
							
* merge nasdaq data with bid-ask spread data and drop missing values;							
data hftomm.Alltrade7;							
merge hftomm.alltrade5 Bidask1;							
by symbol date_new;							
if totalhftmain = '.' then delete;							
if rspread = '.' then delete;							
run;							
							
							
*merge two options data;							
* We use data from optionmetrix for various control variables;							
data hftomm.metrix;							
set hftomm.Optionmetrix1 hftomm.Optionmetrix2;	
date1 = input(put(date,yymmddn8.),8.); *date re-format;	
drop date;	
run;							

data hftomm.metrix;							
set hftomm.metrix;	
rename date1 = date;
run;

							
* we merge options data with the bid-ask data obtained from CRSP;							
* first, we generate new dataset as we need to keep some variables only;							
							
data hftomm.Bidask1metrixmerge;							
set Bidask1;							
keep symbol date_new midquote;							
run;							
							
data hftomm.Bidask1metrixmerge1;							
set hftomm.Bidask1metrixmerge;							
rename symbol = ticker;	
rename 	date_new = date;
run;							
							
							
* sort dataset;							
							
PROC SORT DATA=hftomm.Bidask1metrixmerge1;							
  BY ticker date;							
RUN ;							
							
* sort dataset;							
							
PROC SORT DATA=hftomm.metrix;							
  BY ticker date;							
RUN ;							
							
							
* merge optionmetrix data with nasdaq/bid-ask spread data and drop missing values;							
data hftomm.metrix;							
merge hftomm.Bidask1metrixmerge1 hftomm.metrix;							
by ticker date;							
if best_bid = '.' then delete;							
if midquote = '.' then delete;							
run;							
							
							
*calculating some control variables and droping missing values;							
data hftomm.metrix1;							
set hftomm.metrix;							
if delta = '.' then delete;	*drop if delta missing;						
* we calculated spread based on metrix data too. However, in the analysis, we use intraday spread;							
optionspread = best_offer - best_bid; * dollar spread. we do NOT use it in the main result;							
optionmidprice = (best_offer + best_bid)/2; *midprice;							
optionrelative = optionspread/optionmidprice; * relative/proportional spread. we do NOT use it in the main result;							
absdelta = abs(delta); * compute absolute delta as call and put deltas has different signs;							
optiondollarvolume = volume*optionmidprice; * dollar volume;							
if absdelta = . | vega = . |impl_volatility = . then delete; * drop missing values;							
run;							
							
							
* computing volume weighted average variables by stock/date;							
							
proc means data=hftomm.metrix1 noprint;							
class ticker date;							
weight optiondollarvolume;							
var optionspread optionmidprice optionrelative impl_volatility gamma vega theta absdelta;							
output out=hftomm.metrix2 (drop = _type_ _freq_) mean=;							
run;							
							
							
* drop missing values;							
							
data hftomm.metrix3;							
set hftomm.metrix2;							
if date = . |							
absdelta = . | vega = . |impl_volatility = . then delete; * drop missing values;							
if ticker = ' ' then delete;							
run;							
							
							
* computing daily trading volume;							
							
proc means data=hftomm.metrix1 noprint;							
class ticker date;							
var optiondollarvolume volume;							
output out=hftomm.metrix2volume (drop = _type_ _freq_) sum=optionvolume nominalvolume;							
run;							
							
* drop missing values;							
							
data hftomm.metrix3volume;							
set hftomm.metrix2volume;							
if date = '.' then delete;							
if ticker = ' ' then delete;							
if optionvolume = '.' then delete;							
run;							
							
* next, we merge option volume data with the optionmetrix data;							
* sort by stock and date;							
							
PROC SORT DATA=hftomm.metrix3;							
BY ticker date;							
RUN ;							
							
							
* sort by stock and date;							
PROC SORT DATA=hftomm.metrix3volume;							
BY ticker date;							
RUN ;							
							
							
							
*merge two datasets;							
							
data hftomm.metrix4;							
merge hftomm.metrix3 hftomm.metrix3volume;							
by ticker date;							
run;							
							
							
* drop missing values;							
							
data hftomm.metrix5;							
set hftomm.metrix4;							
if date = . |							
absdelta = . | vega = . |optionvolume = . then delete; * drop missing values;							
if ticker = ' ' then delete;							
run;							
							
* rename;							
							
data hftomm.metrix5;							
set hftomm.metrix5;							
rename ticker = symbol;							
rename date = date_new;							
run;							
							
							
							
* now, it is time to merge optionmetrix data with HFT data;							
							
* sort data;							
PROC SORT DATA=hftomm.Alltrade7;							
  BY symbol date_new;							
RUN ;							
							
* sort data;							
							
PROC SORT DATA=hftomm.metrix5;							
  BY symbol date_new;							
RUN ;							
							
							
*merge HFT data with others;							
							
data hftomm.Alltrade9;							
merge hftomm.Alltrade7 hftomm.metrix5;							
by symbol date_new;							
run;							
							
							
* drop missing values;							
data hftomm.Alltrade10;							
set hftomm.Alltrade9;							
lnoptionvolume = log(optionvolume);							
optionrelative = optionrelative*100; * convert relative spread to percentage terms;							
stockrelative = 100*rspread;* convert relative spread to percentage terms;							
if date_new = . |							
absdelta = . | vega = . | optionvolume = . | totalhftdemand = . then delete; * drop missing values;							
if symbol = ' ' then delete;							
run;							
							
							
							
						
* our main options market spread variable is high-frequency variable;																	
* calculate variables and keep only short-term options;							
data hftomm.optiontradenasdaq1;							
set hftomm.optiontradenasdaq;							
maturitydate = expiry - date; * maturity calculation;							
if maturitydate > 180 then delete; * keep only less than 180;							
spread1 = (ask - bid); * quoted spread;							
midpriceintraday = (ask + bid)/2; * midprice;							
spread2 = (spread1/midpriceintraday)*100; * relative spread in percentage terms;							
unit = 1; * to calculate the total number of transactions. each row is one transaction;							
run;							
							
							
* calculate the total number of options transactions per stock/day;							
proc means data=hftomm.optiontradenasdaq1 noprint;							
class symbol date;							
var unit;							
output out=hftomm.transactions (drop = _type_ _freq_) sum=totaltransactions;							
run;							
							
							
							
* computing volume weighted average variables by stock/date;							
proc means data=hftomm.optiontradenasdaq1 noprint;							
class symbol date;							
weight volume ;							
var spread1 midpriceintraday spread2;							
output out=hftomm.optiontradenasdaq2 (drop = _type_ _freq_) mean=;							
run;							
							
							
* drop missing values and reformat date column. Reformatting is necessary for mergining;							
							
data hftomm.optiontradenasdaq2;							
set hftomm.optiontradenasdaq2;							
date_new=input(put(date, yymmddn8.), 8.);							
*put date_new=;							
drop date;							
if symbol = ' ' then delete;							
if date_new = '.' then delete;							
run;							
							
							
* drop missing values and reformat date column. Reformatting is vital for mergining;							
							
data hftomm.transactions;							
set hftomm.transactions;							
date_new=input(put(date, yymmddn8.), 8.);							
*put date_new=;							
drop date;							
if symbol = ' ' then delete;							
if date_new = '.' then delete;							
run;							
							
							
							
*merge datasets;							
							
proc sort data = hftomm.Alltrade10;							
by symbol date_new;							
run;							
							
proc sort data = hftomm.optiontradenasdaq2;							
by symbol date_new;							
run;							
*merge all datasets;							
							
data hftomm.Alltrade11intraday;							
merge hftomm.Alltrade10 hftomm.optiontradenasdaq2 hftomm.transactions;							
by symbol date_new;							
run;							
							
							
							
* drop missing values;							
							
data hftomm.Alltrade11intraday2;							
set hftomm.Alltrade11intraday;							
if totalhftdemand = '.' then delete;							
if spread2 = '.' then delete;							
run;							
							
							
* drop dublicates if there is any;							
* no duplicates observed;							
proc sort data=hftomm.Alltrade11intraday2 nodupkey;							
by symbol date_new;							
run;							
							
							
*rename columns and calculate inverse price as a control variable;							
data hftomm.Alltrade11intraday2;							
set hftomm.Alltrade11intraday2;							
rename symbol = ticker;							
rename date_new = date;							
inversemidprice = 1/(midpriceintraday);							
run;							
							
							
* our final control is the realized spread;													
* extract date from datetime column;							
							
data hftomm.realizedvoldata1;							
set hftomm.realizedvoldata;							
date = datepart(Date_Time);							
format date date9.;							
run;							
							
							
*sort data;							
							
proc sort data = hftomm.realizedvoldata1;							
by _ric Date_Time;							
run;							
							
							
* calculations;							
							
data hftomm.realizedvoldata2;							
set hftomm.realizedvoldata1;							
midprice = (Close_Bid + Close_Ask)/2;							
run;							
							
* calculations;							
							
data hftomm.realizedvoldata3;							
set hftomm.realizedvoldata2;							
by _ric;							
lagmidprice = ifn(first._ric, ., lag(midprice));							
run;							
							
* calculate return;							
							
data hftomm.realizedvoldata4;							
set hftomm.realizedvoldata3;							
return = (midprice - lagmidprice)/lagmidprice;							
if return = '.' then delete;							
run;							
							
* calculate standard deviation of 5-min return;							
							
proc means data = hftomm.realizedvoldata4 noprint;							
class _ric date;							
var return;							
output out = hftomm.realizedvoldata5 std = realizedvol;							
run;							
							
							
* drop missing values;							
							
data hftomm.realizedvoldata6;							
set hftomm.realizedvoldata5;							
if _ric = ' ' then delete;							
if date = '.' then delete;							
if realizedvol = '.' then delete;							
drop _TYPE_ _FREQ_;							
ticker = substr(_ric,1,index(_ric,".") -1); * TRTH rics have extensions. we drop these extensions to merge;							
run;							
							
*reformatting date;							
							
data hftomm.realizedvoldata6;							
set hftomm.realizedvoldata6;							
date_new=input(put(date, yymmddn8.), 8.);							
*put date_new=;							
drop date;							
run;							
							
							
*rename columns;							
							
data hftomm.realizedvoldata7;							
set hftomm.realizedvoldata6;							
rename date_new = date;							
run;							
							
							
*sort data;							
							
proc sort data  = hftomm.realizedvoldata7;							
by ticker date;							
run;							
							
							
*sort data;							
							
proc sort data  = hftomm.Alltrade11intraday2;							
by ticker date;							
run;							
							
*merge datasets;							
							
data hftomm.Alltrade11intraday2relvol;							
merge hftomm.realizedvoldata7 hftomm.Alltrade11intraday2;							
by ticker date;							
run;							
							
							
*drop missing values;							
							
data hftomm.Alltrade11intraday2relvol1;							
set hftomm.Alltrade11intraday2relvol;							
if totalhftdemand = '.' then delete;							
if realizedvol = '.' then delete;							
run;							
							
							
* we now have all the variables we need in the main dataset;							
* Next, we winsorize all variables;							
							
%winsorise (hftomm.Alltrade11intraday2relvol1, hftomm.Alltrade11intraday2relvol1, quoted, 1); 							
%winsorise (hftomm.Alltrade11intraday2relvol1, hftomm.Alltrade11intraday2relvol1, stockrelative, 1); 							
%winsorise (hftomm.Alltrade11intraday2relvol1, hftomm.Alltrade11intraday2relvol1, optionspread, 1); 							
%winsorise (hftomm.Alltrade11intraday2relvol1, hftomm.Alltrade11intraday2relvol1, optionrelative, 1); 							
%winsorise (hftomm.Alltrade11intraday2relvol1, hftomm.Alltrade11intraday2relvol1, lnoptionvolume, 1); 							
%winsorise (hftomm.Alltrade11intraday2relvol1, hftomm.Alltrade11intraday2relvol1, impl_volatility, 1); 							
%winsorise (hftomm.Alltrade11intraday2relvol1, hftomm.Alltrade11intraday2relvol1, absdelta, 1); 							
%winsorise (hftomm.Alltrade11intraday2relvol1, hftomm.Alltrade11intraday2relvol1, vega, 1); 							
%winsorise (hftomm.Alltrade11intraday2relvol1, hftomm.Alltrade11intraday2relvol1, gamma, 1); 							
%winsorise (hftomm.Alltrade11intraday2relvol1, hftomm.Alltrade11intraday2relvol1, inversemidprice, 1); 							
%winsorise (hftomm.Alltrade11intraday2relvol1, hftomm.Alltrade11intraday2relvol1, totalhftmain, 1); 							
%winsorise (hftomm.Alltrade11intraday2relvol1, hftomm.Alltrade11intraday2relvol1, spread2, 1); 							
%winsorise (hftomm.Alltrade11intraday2relvol1, hftomm.Alltrade11intraday2relvol1, totalhftdemand, 1); 							
%winsorise (hftomm.Alltrade11intraday2relvol1, hftomm.Alltrade11intraday2relvol1, totalhftnondemand, 1); 							
%winsorise (hftomm.Alltrade11intraday2relvol1, hftomm.Alltrade11intraday2relvol1, totalhftsupply, 1); 							
%winsorise (hftomm.Alltrade11intraday2relvol1, hftomm.Alltrade11intraday2relvol1, totalnonhftsupply, 1); 							
%winsorise (hftomm.Alltrade11intraday2relvol1, hftomm.Alltrade11intraday2relvol1, realizedvol, 1); 							
							
							
* Next, we standartize all the variables;							
							
PROC STDIZE DATA = hftomm.Alltrade11intraday2relvol1 method=ustd OUT = hftomm.Alltrade11intraday2relvol1std;							
VAR quoted stockrelative optionspread optionrelative lnoptionvolume impl_volatility absdelta vega gamma 							
inversemidprice totalhftmain spread2 totalhftdemand totalhftnondemand totalhftsupply totalnonhftsupply realizedvol;							
RUN;							
							
							
							
*demean variables;							
*we demean variables for fixed effects regression. This is because proc panel does not have an option to obtain double clustered standard errors;							
							
							
%demean (hftomm.Alltrade11intraday2relvol1std, quoted); 							
%demean (hftomm.Alltrade11intraday2relvol1std, stockrelative); 							
%demean (hftomm.Alltrade11intraday2relvol1std, optionspread); 							
%demean (hftomm.Alltrade11intraday2relvol1std, optionrelative); 							
%demean (hftomm.Alltrade11intraday2relvol1std, lnoptionvolume); 							
%demean (hftomm.Alltrade11intraday2relvol1std, impl_volatility); 							
%demean (hftomm.Alltrade11intraday2relvol1std, absdelta); 							
%demean (hftomm.Alltrade11intraday2relvol1std, vega); 							
%demean (hftomm.Alltrade11intraday2relvol1std, gamma); 							
%demean (hftomm.Alltrade11intraday2relvol1std, inversemidprice); 							
%demean (hftomm.Alltrade11intraday2relvol1std, totalhftmain);							
%demean (hftomm.Alltrade11intraday2relvol1std, spread2);							
%demean (hftomm.Alltrade11intraday2relvol1std, totalhftdemand);							
%demean (hftomm.Alltrade11intraday2relvol1std, totalhftnondemand);							
%demean (hftomm.Alltrade11intraday2relvol1std, totalhftsupply);							
%demean (hftomm.Alltrade11intraday2relvol1std, totalnonhftsupply);							
%demean (hftomm.Alltrade11intraday2relvol1std, realizedvol);							
							
							
							
* Table 2: Summary statistics. We use non-standartized data here;							
							
proc means data = hftomm.Alltrade11intraday2relvol1 mean median stddev; var totalhftmain totalhftsupply totalhftdemand 							
totalnonhftsupply totalhftnondemand stockrelative realizedvol spread2 inversemidprice lnoptionvolume impl_volatility							
absdelta gamma vega  ;							
run;							
							
* Table 3: Estimating the main OLS model;							
							
* Column(i);							
							
%FirmTimeCluster(hftomm.Alltrade11intraday2relvol1std, dm2_spread2, dm2_totalhftmain							
dm2_stockrelative  dm2_realizedvol dm2_lnoptionvolume							
dm2_impl_volatility dm2_inversemidprice dm2_absdelta dm2_vega dm2_gamma, noint, baseline_model)							
							
							
* Two way fixed effect results with double-clustered standard errors are generated in temp file. 							
Thompson, S.B., 2011. Simple formulas for standard errors that cluster by both firm and time. 							
Journal of financial Economics, 99(1), pp.1-10.;							
							
proc print data = temp;							
run;							
							
* Column(ii);							
							
%FirmTimeCluster(hftomm.Alltrade11intraday2relvol1std, dm2_spread2, dm2_totalhftsupply dm2_totalnonhftsupply							
dm2_stockrelative  dm2_realizedvol dm2_lnoptionvolume							
dm2_impl_volatility dm2_inversemidprice dm2_absdelta dm2_vega dm2_gamma, noint, baseline_model)							
							
* Column(iii);							
							
proc print data = temp;							
run;							
							
%FirmTimeCluster(hftomm.Alltrade11intraday2relvol1std, dm2_spread2, dm2_totalhftdemand dm2_totalhftnondemand							
dm2_stockrelative  dm2_realizedvol dm2_lnoptionvolume							
dm2_impl_volatility dm2_inversemidprice dm2_absdelta dm2_vega dm2_gamma, noint, baseline_model)							
							
proc print data = temp;							
run;							
							
							
							
							
							
							
							
							
							
							
							
							
							
							
							
