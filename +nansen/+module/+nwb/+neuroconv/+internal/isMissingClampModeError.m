function tf = isMissingClampModeError(exception)
%isMissingClampModeError - Detect NeuroConv's missing clamp mode assertion
%   tf = isMissingClampModeError(exception) is true when exception, or any
%   exception in its cause tree, carries NeuroConv's complaint that an
%   Icephys session has no icephys_experiment_type. NeuroConv raises it as
%   a bare Python AssertionError, so the message text is its only
%   signature; the fragment matched here is what the pinned NeuroConv
%   release prints.
%
%   See also nansen.module.nwb.conversion.builtin.convertWithNeuroconv,
%   nansen.module.nwb.neuroconv.runConversion

    arguments
        exception (1,1) MException
    end

    import nansen.module.nwb.neuroconv.internal.isMissingClampModeError

    assertionFragment = "'icephys_experiment_type' should be";

    tf = contains(exception.message, assertionFragment);
    for i = 1:numel(exception.cause)
        tf = tf || isMissingClampModeError(exception.cause{i});
    end
end
