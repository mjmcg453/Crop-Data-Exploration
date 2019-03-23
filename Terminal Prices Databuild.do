clear all
set more off, perm
set type double, perm
set excelxlsxlargefile on


global output "C:\Users\admin\Documents\Work Docs\Starling\Crop Data"
global data  "C:\Users\admin\Documents\Work Docs\Starling\Crop Data\data" 

local 	temp 	= c(tmpdir)
global 	temp 	"`temp'"

******************************
foreach city in Atlanta Baltimore Boston Chicago Columbia Dallas Miami "New York" "Los Angeles" Philadelphia "San Francisco"  {
	
	import excel using "$data\Terminal - `city'.xlsx", clear firstrow

	foreach var of varlist _all {
		capture assert mi(`var')
		if !_rc {
		drop `var'
			 }
		}	
	
	if CityName[1] == "ATLANTA" {
		save "$temp\appnd", replace
		}
	else {
		append using "$temp\appnd.dta", force
		save "$temp\appnd", replace
		}
	}
use "$temp\appnd.dta", clear

**Gen
g month = month(Date)
g year = year(Date)
drop if year==2019
g organic = Type=="Organic"
drop Type
g avg_price = (MostlyHigh+MostlyLow)/2
replace avg_price = (HighPrice + LowPrice)/2 if avg_price==.
drop if avg_price ==.

preserve
import excel "$data\Imports CX.xlsx", clear firstrow
replace Origin = trim(Origin)
save "$temp\importscx", replace
restore

merge m:1 Origin using "$temp\importscx", nogen

**Tomatoes
replace Variety = "RED" if regexm(CommodityName,"CHERRY") & Variety==""

**Lettuce
replace Variety = "BABY RED" if Commodity == "ROMAINE, BABY RED"
replace Commodity = "LETTUCE, ROMAINE" if Commodity == "ROMAINE, BABY RED"


**Categories for output
g cat = ""
foreach crop in ARRUGULA BOK COLLARD KALE LETTUCE MESCULIN ROMAINE SPINACH {
replace cat = "Leafy Greens" if regexm(Commodity, "`crop'")
}

foreach crop in BASIL CILANTRO OREGANO PARSLEY ROSEMARY THYME{
replace cat = "Herbs" if regexm(Commodity, "`crop'")
}

replace cat = "Peppers" if regexm(Commodity, "PEPPER")
replace cat = "Fruit" if regexm(Commodity, "STRAWBERRIES")
replace cat = "Tomatoes" if regexm(Commodity, "TOMATOES")
replace cat = "Mushrooms" if regexm(Commodity, "MUSHROOMS")

assert cat!=""

***LBS
g pounds = .
forval i = 1/50{
replace pounds = `i' if regexm(Package, "`i' lb") & ~regexm(Package, "-") & ~regexm(Package,"/")
}

forval i = 1/6 {
replace pounds = `i'*2.2 if regexm(Package, "`i' kg")
}

foreach x in 2 3 4 6 8 9 10 12{
	foreach y in 1 2 3 4 {
	replace pounds = `x'*`y' if regexm(Package,"`x' `y'-lb")
	}
}

replace pounds = 2.2 if regexm(Package, "2.2 lb")
replace pounds = 2.5 if regexm(Package, "2.5 lb")
replace pounds = .5 if  regexm(Package, "1/2 lb film bags")
replace pounds = 10 if regexm(Package,"4 2-1/2 lb")



foreach n in 6 8 9 10 12 15 16 20{
	foreach z in 3.5 4 6 8 8.8 9 10 10.5 11 12 13 14 16 18 22 23 24.2 {
		replace pounds = `n'*`z'/16 if regexm(Package, "`n' `z'-oz")
	}
}
replace pounds = pounds*3 if regexm(Package, "(3 count)")
replace pounds = 5.25 if regexm(Package, "24 3 1/2-oz")
replace pounds = 7.875 if regexm(Package, "36 3-1/2 oz")
replace pounds = 8.75 if inlist(Package, "cartons 10 tubes 3s 14-oz", "cartons 10 tubes 4s 14-oz")



assert pounds!=. if regexm(Package, "lb")
assert pounds!=. if regexm(Package, "kg")
assert pounds!=. if regexm(Package, "oz")

g price_per_lb = avg_price / pounds

***Bunches
foreach i in 12 24 30 36{
replace ItemSize = "`i's" if regexm(ItemSize,"`i's") & regexm(ItemSize, "(f|bchd)")
}
g bunches = .
forval i = 1/60 {
replace bunches = `i' if ItemSize== "`i's"
}
*Simple average
replace bunches = 14 if ItemSize=="12-16s"
replace bunches = 16.5 if ItemSize=="15-18s"
replace bunches = 17 if ItemSize=="16-18s"
replace bunches = 20 if ItemSize=="16-24s"

g price_per_bunch = avg_price / bunches



**Output
*daily
order cat Commodity Variety SubVariety City Package ItemSize Environment organic year month Date pounds avg_price price_per_lb LowPrice HighPrice MostlyLow MostlyHigh import
sort cat Commodity Variety SubVariety City Package ItemSize Environment organic import year month
save "$temp\preoutput", replace
use "$temp\preoutput", clear
export excel using "$output\19.03.21 Fruits & Veg Wholesale Price Summaries.xlsx", sheet("Prices - Daily") sheetreplace firstrow(variables)

*monthly
preserve
bysort Commodity Variety SubVariety City Origin Package ItemSize Environment organic import year month: egen std_avg_price = sd(avg_price)
collapse (mean) LowPrice HighPrice MostlyLow MostlyHigh avg_price price_per_lb pounds, by(cat Commodity Variety SubVariety City Origin Package ItemSize year month  Environment import organic std_avg_price)
order cat Commodity Variety SubVariety City Origin Package ItemSize Environment organic year month pounds avg_price std LowPrice HighPrice MostlyLow MostlyHigh import
export excel using "$output\19.03.21 Fruits & Veg Wholesale Price Summaries.xlsx", sheet("Prices - Monthly") sheetreplace firstrow(variables)
restore



*Price by pound
preserve
drop if price_per_lb == .
collapse (mean) price_per_lb, by(cat Commodity Variety SubVariety City Origin import year month Environment organic)
replace CityName = subinstr(CityName, " ","",.)
reshape wide price_per_lb, i(cat Commodity Variety SubVariety Origin import year month Environment organic) j(City)string
foreach city in ATLANTA BALTIMORE BOSTON DALLAS MIAMI NEWYORK LOSANGELES PHILADELPHIA SANFRANCISCO {
ren price_per_lb`city' `city'
}
ren (LOSANGELES NEWYORK SANFRANCISCO) (LOS_ANGELES NEW_YORK SAN_FRANCISCO)
sort cat Commodity Variety SubVariety Origin Environment organic import year month

export excel using "$output\19.03.21 Fruits & Veg Wholesale Price Summaries.xlsx", sheet("Price per Pound") sheetreplace firstrow(variables)
restore



*Price by bunch
preserve
drop if price_per_bunch == .
collapse (mean) price_per_bunch, by(cat Commodity Variety SubVariety City Origin import year month Environment organic)
replace CityName = subinstr(CityName, " ","",.)
reshape wide price_per_bunch, i(cat Commodity Variety SubVariety Origin import year month Environment organic) j(City)string
foreach city in ATLANTA BALTIMORE BOSTON DALLAS MIAMI NEWYORK LOSANGELES PHILADELPHIA SANFRANCISCO {
ren price_per_bunch`city' `city'
}
ren (LOSANGELES NEWYORK SANFRANCISCO) (LOS_ANGELES NEW_YORK SAN_FRANCISCO)
sort cat Commodity Variety SubVariety Origin Environment organic import year month

export excel using "$output\19.03.21 Fruits & Veg Wholesale Price Summaries.xlsx", sheet("Price per Bunch") sheetreplace firstrow(variables)
restore


