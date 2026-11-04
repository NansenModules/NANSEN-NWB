function value = iso8601ToDatetime(text)
%iso8601ToDatetime - Read ISO 8601 text as a datetime, keeping its offset
%   VALUE = iso8601ToDatetime(TEXT) parses text of the form
%   "2026-05-10T14:30:15.250+02:00". The UTC offset becomes the datetime's
%   time zone, so the wall-clock time and the offset both survive; "Z"
%   becomes UTC. Text without an offset gives a datetime without a time
%   zone. Fractional seconds are optional.
%
%   VALUE is empty when TEXT is not of that form, so a caller can fall
%   back to another reading of the text.
%
%   See also nansen.module.nwb.internal.datetimeToIso8601, datetime

    arguments
        text (1,1) string
    end

    value = datetime.empty;
    characters = char(strtrim(text));

    % The date, the T and the time of day take 19 characters:
    % 2026-05-10T14:30:15. Anything shorter is not this form.
    if numel(characters) < 19 || characters(11) ~= 'T'
        return
    end

    timeZone = "";
    if characters(end) == 'Z'
        timeZone = "UTC";
        characters(end) = [];
    elseif numel(characters) >= 25 && any(characters(end-5) == '+-') && characters(end-2) == ':'
        timeZone = string(characters(end-5:end));
        characters(end-5:end) = [];
    end

    % Anything after the 19 characters of the date and time of day must be
    % a decimal point followed by at least one digit of the seconds.
    inputFormat = "uuuu-MM-dd'T'HH:mm:ss";
    if numel(characters) > 19
        fractionDigits = numel(characters) - 20;
        if characters(20) ~= '.' || fractionDigits < 1
            return
        end
        inputFormat = inputFormat + "." + repmat('S', 1, fractionDigits);
    end

    try
        if timeZone == ""
            value = datetime(string(characters), InputFormat=inputFormat);
        else
            value = datetime(string(characters), InputFormat=inputFormat, TimeZone=timeZone);
        end
    catch
        % Not a timestamp after all, for example a date with letters in
        % it. The caller decides what else the text could be.
        value = datetime.empty;
    end
end
