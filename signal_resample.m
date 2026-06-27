% signal_resample.m
% Load or generate a signal, then resample

% Option A: Use MATLAB's built-in audio (handel)
if exist('handel.mat','file')
    load handel.mat;  % loads y and Fs
    x = y; fs = Fs;
else
    % Option B: Generate a chirp signal if handel.mat is missing
    fs = 16000;
    t = 0:1/fs:3;
    x = chirp(t,100,3,3000)';  % sweep 100 Hz → 3 kHz
end

% Normalize
x = x / max(abs(x));

% Save to data folder
audiowrite(fullfile('data','original.wav'), x, fs);

% Plot first 20 ms of signal
figure;
plot((1:round(0.02*fs))/fs, x(1:round(0.02*fs)));
xlabel('Time (s)'); ylabel('Amplitude');
title('Original signal (first 20 ms)');
saveas(gcf, fullfile('figures','orig_segment.png'));

% ----------------------
% Resampling
newFs = 8000;   % target sample rate
try
    xr = resample(x, newFs, fs);   % Signal Processing Toolbox
    disp('Resampled using resample()');
catch
    % Toolbox-free fallback (simple interpolation)
    t_old = (0:length(x)-1)/fs;
    t_new = (0:1/newFs:(length(x)-1)/fs);
    xr = interp1(t_old, x, t_new, 'linear')';
    disp('Resampled using interp1 fallback');
end

% Save resampled signal
audiowrite(fullfile('data','resampled.wav'), xr, newFs);
