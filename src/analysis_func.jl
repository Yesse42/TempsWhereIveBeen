using CSV, DataFrames, Plots, Statistics, Dates
gr()

function analyze_my_data(data; timecol = :date_time, tempcol = :air_temp_set_1, n_hours_needed = 22, units = "C")

    data = select(data, tempcol=>"Temp", timecol => :datetime)

    dropmissing!(data)

    function transform_groupby_combine(dataframe, transformargs, groupcols, combineargs)
        dataframe = transform(dataframe, transformargs...)
        grouped = groupby(dataframe, groupcols)
        return combine(grouped, combineargs...)
    end

    #First we need to reduce to hourly data, for the sake of my missing data check
    datacol = "Temp"

    myfunc(func)= f(x) = if all(ismissing(y) for y in x) missing else func(skipmissing(x)) end

    #These functions are used on the hourly level to ensure the max and min are not diluted by first taking an hourly mean
    stat_funcs = [maximum, mean, minimum]
    hourlynames = ["Max", "Mean", "Min"]

    hourly = transform_groupby_combine(data, [:datetime=>ByRow(x->round(x, Hour(1)))=>:datetime], :datetime, [datacol.=>myfunc.(stat_funcs).=>hourlynames])

    stat_names = ["High", "Daily Mean", "Low"]
    daily_names = stat_names .* " " .* datacol

    
    function picky_stat_func(func, thresh)
        function f(data)
            if length(data) < thresh
                missing
            else
                func(data)
            end
        end
    end

    daily = transform_groupby_combine(hourly, [:datetime=>ByRow(x->round(x, Day(1), RoundDown))=>:datetime], :datetime, 
                                        [hourlynames.=>picky_stat_func.(stat_funcs, n_hours_needed).=>daily_names])

    dropmissing!(daily)

    #Now group those for each month long period
    second_stat_names = ["Warmest", "Mean", "Coldest"]
    monthly_names = permutedims(second_stat_names) .* " " .* daily_names

    monthly_data = transform_groupby_combine(daily, [:datetime=>ByRow(x->round(x, Month(1), RoundDown))=>:datetime], :datetime, 
                [daily_names.=>permutedims(stat_funcs).=>monthly_names])

    #Now calculate the monthly highest high, mean high, coldest high, highest low, so on and so forth
    summary_stat_names = ["Warmest High Temp", "Mean High Temp", "Coldest High Temp", "Warmest Daily Mean Temp", "Mean Daily Mean Temp", 
                            "Coldest Daily Mean Temp", "Warmest Low Temp", "Mean Low Temp", "Coldest Low Temp"][end:-1:begin]
    plotdata = reduce(hcat, [monthly_data[!, name] for name in summary_stat_names])'

    proper_date_format = dateformat"mm/yyyy"

    date_labels = Dates.format.(monthly_data.datetime, proper_date_format)

    myp = heatmap(plotdata; xticks = (axes(plotdata, 2), date_labels), xrotation=35., yticks = (axes(plotdata, 1), summary_stat_names), 
                    title="Climate summary of wherever I've been the last few months", titlefontsize=12, color = :coolwarm, 
                    size = 1e2.*(10,5), colorbar_title = "Temperature (º$units)", margin = 10Plots.mm)

    annotate!(myp, [(j, i, Plots.text(string(round(Int, plotdata[i, j])), 8)) for i in axes(plotdata, 1), j in axes(plotdata, 2)]...)

    display(myp)

    daily_plotdata = reduce(hcat, [daily[!, name] for name in daily_names])

    p2 = plot(daily.datetime, daily_plotdata; label = permutedims(daily_names), ylabel = "Temp (º$units)", xlabel = "Date", 
        title = "Temp from wherever I spent the day", legend = :bottomleft, yminorticks = 5, 
        xticks = (monthly_data.datetime, date_labels), xrotation = 35, size = 1e2 .* (10,6), margin = 10Plots.mm)

    display(p2)

    return (timeseries = p2, table = myp)
end