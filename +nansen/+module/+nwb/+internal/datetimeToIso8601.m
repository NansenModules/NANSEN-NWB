function text = datetimeToIso8601(value)
%datetimeToIso8601 - Write a datetime as ISO 8601 text with its UTC offset
%   TEXT = datetimeToIso8601(VALUE) returns VALUE as text of the form
%   "2026-05-10T14:30:15.250+02:00", with "Z" for UTC. A datetime without
%   a time zone is written without an offset, and reads back without one,
%   so that the conversion runner can refuse it as it would the datetime.
%
%   Example: Round-trip a session start time through JSON
%       text = nansen.module.nwb.internal.datetimeToIso8601( ...
%           datetime(2026, 5, 10, 14, 30, 0, TimeZone="Europe/Oslo"));
%       restored = nansen.module.nwb.internal.iso8601ToDatetime(text);
%
%   See also nansen.module.nwb.internal.iso8601ToDatetime,
%   nansen.module.nwb.config.NWBFileConfiguration

    arguments
        value (1,1) datetime
    end

    if value.TimeZone == ""
        text = string(value, "uuuu-MM-dd'T'HH:mm:ss.SSS");
    else
        text = string(value, "uuuu-MM-dd'T'HH:mm:ss.SSSXXX");
    end
end
