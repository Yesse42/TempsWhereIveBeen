#First Download Julia, then use Pkg
using Pkg

#For convenience, change the directory to the directory of this file
cd(@__DIR__)

#This should be the path to the TempsWhereIveBeen Directory
pkgdir = "../"

#Now activate the package
Pkg.activate(joinpath(pwd(), pkgdir))

#Download the necessary packages
Pkg.instantiate()

#Now use the package
using TempsWhereIveBeen

#Go get a synoptic api token and put it here
my_api_token  = "nunya business, gotta go get your own from synoptic.com (after making a free account) and put it here as an alphanumeric string (in these same quotes)"

#Now download the data
#Leave archivedir as the empty string "" if you want to download new copies from synoptic every time (not recommended)
#The station_mapping file should map each station (a valid synoptic station id) to a positive integer, and the station_times file should be a csv mapping 
#each location's associated positive integer to the beginning of your time there, with the last entry mapping 0 to the end of your time range.
#You can either edit the example CSVs or write your own and provide the paths as arguments to this function; just be sure to keep the 
#formatting the same. If you use a different delimiter, then change delim; also keep the column names the same.
#Lastly, your vars must be an array of valid mesowest variable names
data = download_mesowest_requests("station_mapping.csv", "station_times.csv"; token = my_api_token, 
                                    archivedir = "archived", vars = ["air_temp_set_1"], delim = ", ")

#Celsius to Fahrenheit (dots indicate operations broadcast over arrays)
data.air_temp_set_1 .= data.air_temp_set_1 .* (9/5) .+ 32

#Get the two plots
plots = analyze_my_data(data; units = "F")

#Now display the two plots
display.(Tuple(plots))
#The dots indicate an elementise function call, as savefig has two plots to save
#We need to bring the package Plots.jl into scope to save
using Plots
savefig.([plots.timeseries, plots.table], ["time_series.png", "table.png"])

#To actually run this file, you can use the command line (assuming julia is in you path) by writing in your shell "julia <this file's path>"
