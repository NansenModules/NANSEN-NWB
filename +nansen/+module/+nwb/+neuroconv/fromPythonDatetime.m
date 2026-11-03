function value = fromPythonDatetime(pythonDatetime)
%fromPythonDatetime - Convert a Python datetime to a MATLAB datetime
%   VALUE = fromPythonDatetime(pythonDatetime) returns the datetime.datetime
%   pythonDatetime as a MATLAB datetime. An aware Python datetime gives a
%   datetime whose time zone is its UTC offset, "+02:00" or "UTC", so the
%   wall-clock time and the offset both survive; a naive one gives a
%   datetime without a time zone.
%
%   This is the inverse of the datetime case of toPythonValue.
%
%   See also nansen.module.nwb.neuroconv.toPythonValue, datetime

    arguments
        pythonDatetime (1,1) py.datetime.datetime
    end

    second = double(pythonDatetime.second) + double(pythonDatetime.microsecond) / 1e6;

    if isequal(pythonDatetime.tzinfo, py.None)
        value = datetime(double(pythonDatetime.year), double(pythonDatetime.month), ...
            double(pythonDatetime.day), double(pythonDatetime.hour), ...
            double(pythonDatetime.minute), second);
        return
    end

    offsetSeconds = double(pythonDatetime.utcoffset().total_seconds());
    if offsetSeconds == 0
        timeZone = "UTC";
    else
        if offsetSeconds < 0
            signText = "-";
        else
            signText = "+";
        end
        offsetMinutes = round(abs(offsetSeconds) / 60);
        timeZone = sprintf("%s%02d:%02d", signText, ...
            floor(offsetMinutes / 60), mod(offsetMinutes, 60));
    end

    value = datetime(double(pythonDatetime.year), double(pythonDatetime.month), ...
        double(pythonDatetime.day), double(pythonDatetime.hour), ...
        double(pythonDatetime.minute), second, TimeZone=timeZone);
end
