function recording = play_record_audio(waveform, settings)
%PLAY_RECORD_AUDIO Base-MATLAB asynchronous recording with blocking playback.
% Inputs: waveform real mono [T x 1] full scale, settings. Output: real mono
% recording [samples x 1]. Device clocks/start times need not be synchronized.
% Physical operation: plays audible sound and records the microphone.
assert(isreal(waveform) && max(abs(waveform)) <= 1, 'Invalid audio samples.');
fprintf('Disable microphone AGC, noise suppression, echo cancellation and audio enhancements.\n');
if settings.audioInputDevice < 0
    recorder = audiorecorder(settings.sampleRate, settings.audioBits, 1);
else
    recorder = audiorecorder(settings.sampleRate, settings.audioBits, 1, settings.audioInputDevice);
end
if settings.audioOutputDevice < 0
    player = audioplayer(waveform, settings.sampleRate, settings.audioBits);
else
    player = audioplayer(waveform, settings.sampleRate, settings.audioBits, settings.audioOutputDevice);
end
cleanup = onCleanup(@() stop(recorder));
record(recorder);
pause(settings.recordLeadSeconds);
playblocking(player);
pause(settings.recordTailSeconds);
stop(recorder);
recording = getaudiodata(recorder, 'double');
clear cleanup;
end
