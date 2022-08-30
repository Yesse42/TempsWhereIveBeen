using HTTP, Dates, DataFrames, JSON
const t_series_url = "https://api.synopticdata.com/v2/stations/timeseries?"

const standard_dateformat = dateformat"YYYYmmddHHMM"

const key_type = Union{AbstractString, Symbol}

function param_parser(key::key_type, value::String)
    return "&$key=$value"
end

function param_parser(key::key_type, value::TimeType)
    return "&$key=$(Dates.format(DateTime(value), standard_dateformat))"
end

function param_parser(key::key_type, value)
    insert_val = nothing
    if length(value) == 1
        insert_val = value
    else
        insert_val = join(string.(value) .* ",")
        insert_val = rstrip(insert_val, ',')
    end
    return "&$key=$insert_val"
end

function request_timeseries(params_dict)
    request_params = join(param_parser(pair...) for pair in params_dict)
    request_params
    request = join((t_series_url, request_params))
    rawbits = HTTP.get(request)
    return JSON.parse(String(rawbits.body))
end

