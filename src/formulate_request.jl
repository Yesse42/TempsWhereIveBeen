include("http_get.jl")

using CSV

const std_dateformat = dateformat"y/m/d-H:M:s"
const time_var_name = "date_time"
const mesowest_dateformat = dateformat"yyyy-mm-ddTHH:MM:ssZ"

function between(data, tup)
    tup[1] <= data < tup[2]
end

function download_mesowest_requests(station_mapping_csv, start_date_csv; vars = ["air_temp_set_1"], delim = ", ", token, archivedir = "")
    start_dates = CSV.read(start_date_csv, DataFrame; delim)
    station_mappings = CSV.read(station_mapping_csv, DataFrame; delim)
    dropmissing!.((start_dates, station_mappings))
    start_dates.startdate = parse.(DateTime, start_dates.startdate, std_dateformat)
    start_time, finish_time = extrema(start_dates.startdate)

    station_data_dict = Dict{Int, DataFrame}()
    !isempty(archivedir) && mkpath(archivedir)
    #Now download the data for each station
    for (station, num) in eachrow(station_mappings)
        println("$station")
        succesfully_unarchived = false
        archived_file_path = joinpath(archivedir, "$station.csv")
        if !isempty(archivedir) && isfile(archived_file_path)
            archived_data = CSV.read(archived_file_path, DataFrame)
            has_all_cols = all(in.(vars, Ref(names(archived_data))))
            archive_por = extrema(archived_data.date_time)
            has_all_times = archive_por[1] <= start_time + Day(1) && finish_time - Day(1) <= archive_por[2]
            if has_all_cols && has_all_times
                station_data_dict[num] = archived_data
                succesfully_unarchived = true
            end
        end
        if !succesfully_unarchived
            request_params = Dict(:stid => station, :start => start_time, :end => finish_time, :token => token)
            data = request_timeseries(request_params)
            var_data = [replace!(data["STATION"][1]["OBSERVATIONS"][var_name], nothing=>missing) for var_name in vars]
            data_as_dataframe = DataFrame([[data["STATION"][1]["OBSERVATIONS"][time_var_name]]; var_data], [time_var_name; vars])
            data_as_dataframe[!, time_var_name] = parse.(DateTime, data_as_dataframe[!, time_var_name], mesowest_dateformat)
            sort!(data_as_dataframe, "date_time")
            station_data_dict[num] = data_as_dataframe
            if !isempty(archivedir)
                CSV.write(joinpath(archivedir, "$station.csv"), data_as_dataframe)
                println("$station data archived")
            end
        end
        println("Used Archive: $succesfully_unarchived")
    end
    #Now actually stitch the different datasets together, in the most naive way possible because I am lazy
    data_to_combine = DataFrame[]
    for ((num, startdate), enddate) in zip(eachrow(start_dates[1:end-1, :]), start_dates.startdate[2:end])
        data = station_data_dict[num]
        times = data[!, time_var_name]
        push!(data_to_combine, data[between.(times, Ref((startdate, enddate))), :])
    end
    return reduce(vcat, data_to_combine)
end