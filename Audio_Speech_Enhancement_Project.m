% audio_speech_enhancement_fixed.m
% End-to-end Speech Enhancement & Analysis (CORRECTED VERSION)
% Fixes: Signal timing, SNR scaling logic, Minimum Stats tracking
%
% Usage: Run in MATLAB. Check 'results/' for summary.txt

clear; close all; clc;

%% ---------------------------
%% 1. Setup folders & parameters
%% ---------------------------
projectRoot = pwd;
dataDir    = fullfile(projectRoot,'data');
figDir     = fullfile(projectRoot,'figures');
resultsDir = fullfile(projectRoot,'results');
if ~exist(dataDir,'dir'), mkdir(dataDir); end
if ~exist(figDir,'dir'), mkdir(figDir); end
if ~exist(resultsDir,'dir'), mkdir(resultsDir); end
rng(42); % Fixed seed for reproducibility

%% ---------------------------
%% 2. Load or generate original audio
%% ---------------------------
wavFile = fullfile(dataDir,'original.wav');

% --- CORRECTION 1: Signal Timing ---
% We ensure the first 0.6 seconds are SILENCE so the noise estimator 
% captures pure noise without clipping the first syllable.
fs = 16000;
t = (0:1/fs:6)'; % 6 seconds
x = zeros(size(t));

% Syllables moved later (starting at 0.6s instead of 0.2s)
starts = [0.6 1.4 2.2 3.1 4.0 4.8]; 
durations = 0.5*ones(size(starts));
f0s = [120 150 100 130 90 160];

for k = 1:length(starts)
    idx = t >= starts(k) & t <= (starts(k)+durations(k));
    % Harmonics added to make it sound more like speech (not just pure sine)
    base = sin(2*pi*f0s(k)*t(idx));
    harm1 = 0.5 * sin(2*pi*2*f0s(k)*t(idx)); 
    x(idx) = 0.7 * (base + harm1) .* (hann(sum(idx)));
end

% Add slight unvoiced fricative segments
x = x + 0.005*randn(size(x));

% Normalize Clean Signal
x = x / max(abs(x)+eps);
audiowrite(wavFile, x, fs);
fprintf('Generated clean audio (Fs=%d Hz, %.2f s). First 0.6s is silence.\n', fs, length(x)/fs);

%% ---------------------------
%% 3. Create noisy signal
%% ---------------------------
target_snr_db = 5; 
clean_power = mean(x.^2);
noise_white = randn(size(x));

% Scale white noise
noise_power_desired = clean_power / (10^(target_snr_db/10));
noise_white = sqrt(noise_power_desired / mean(noise_white.^2)) * noise_white;

% Add periodic interference
hum = 0.05 * sin(2*pi*50*t);            % 50 Hz hum
drift = 0.05 * sin(2*pi*0.5*t);         % Low freq drift

x_noisy = x + noise_white + hum + drift;
audiowrite(fullfile(dataDir,'noisy.wav'), x_noisy/max(abs(x_noisy)), fs);
fprintf('Noisy audio created (Target Input SNR = %.1f dB).\n', target_snr_db);

%% ---------------------------
%% 4. STFT Processing
%% ---------------------------
winLen = 512; % Smaller window for better time resolution
hop = 128;    % 75% overlap
nfft = 512;
win = hamming(winLen,'periodic');

S_clean = my_stft(x, win, hop, nfft);
S_noisy = my_stft(x_noisy, win, hop, nfft);

taxis = (0:size(S_clean,2)-1) * (hop/fs);
faxis = (0:nfft-1) * (fs/nfft);

%% ---------------------------
%% 5. Noise Estimation (First 0.5s)
%% ---------------------------
% Because we shifted speech to 0.6s, this is now safe
noise_frames_idx = 1:floor(0.5*fs/hop);
noiseSpec = mean(abs(S_noisy(:,noise_frames_idx)).^2, 2); 

%% ---------------------------
%% Algorithm 1: Spectral Subtraction
%% ---------------------------
mag_noisy = abs(S_noisy);
phase_noisy = angle(S_noisy);
noiseMagEst = sqrt(noiseSpec);

% Subtraction with a "spectral floor" (beta) to reduce musical noise
beta = 0.01; 
mag_sub = max(mag_noisy - 2.0 * repmat(noiseMagEst,1,size(mag_noisy,2)), beta * mag_noisy);

S_sub = mag_sub .* exp(1j*phase_noisy);
y_sub = my_istft(S_sub, win, hop, nfft);

%% ---------------------------
%% Algorithm 2: Wiener Filtering
%% ---------------------------
power_noisy = abs(S_noisy).^2;
prior_SNR = max(power_noisy - repmat(noiseSpec,1,size(power_noisy,2)), 0) ./ (repmat(noiseSpec,1,size(power_noisy,2)) + eps);
H_wiener = prior_SNR ./ (prior_SNR + 1 + eps); % Standard Wiener Gain

S_wiener = H_wiener .* S_noisy;
y_wiener = my_istft(S_wiener, win, hop, nfft);

%% ---------------------------
%% Algorithm 3: Minimum Statistics (CORRECTED)
%% ---------------------------
% --- CORRECTION 3: Leaky Minimum ---
% Allows the noise floor to rise if background noise increases
alpha_smooth = 0.9;
P_smooth = abs(S_noisy(:,1)).^2;
noise_floor_trk = abs(S_noisy(:,1)).^2;
S_min = zeros(size(S_noisy));

for k = 1:size(S_noisy,2)
    Pk = abs(S_noisy(:,k)).^2;
    P_smooth = alpha_smooth * P_smooth + (1-alpha_smooth) * Pk;
    
    % Track minimum, but leak upwards slightly (x 1.005)
    % If current power is higher than floor, floor rises slowly.
    % If current power is lower, floor drops immediately.
    noise_floor_trk = min(noise_floor_trk * 1.005, P_smooth);
    
    % Simple gain based on this tracked noise
    current_snr = max(0, (Pk - noise_floor_trk)./(noise_floor_trk+eps));
    G_min = current_snr ./ (current_snr + 1 + eps);
    
    S_min(:,k) = G_min .* S_noisy(:,k);
end

y_min = my_istft(S_min, win, hop, nfft);

%% ---------------------------
%% Algorithm 4: FIR Bandpass
%% ---------------------------
b_fir = fir1(100, [300 3400]/(fs/2));
y_fir = filter(b_fir, 1, x_noisy);

%% ---------------------------
%% 6. Evaluation (CORRECTED METRICS)
%% ---------------------------
% Truncate to match lengths
L = min([length(x), length(x_noisy), length(y_sub), length(y_wiener), length(y_min), length(y_fir)]);
x_ref = x(1:L);

% --- CORRECTION 2: Use Scale-Invariant SNR ---
% We do NOT normalize y_* before sending to compute_snr. 
% The function will handle scaling.

snr_before = compute_si_snr(x_ref, x_noisy(1:L));
snr_sub    = compute_si_snr(x_ref, y_sub(1:L));
snr_wiener = compute_si_snr(x_ref, y_wiener(1:L));
snr_min    = compute_si_snr(x_ref, y_min(1:L));
snr_fir    = compute_si_snr(x_ref, y_fir(1:L));

% Save normalized audio for listening
audiowrite(fullfile(dataDir,'out_spec_sub.wav'), y_sub/max(abs(y_sub)), fs);
audiowrite(fullfile(dataDir,'out_wiener.wav'), y_wiener/max(abs(y_wiener)), fs);
audiowrite(fullfile(dataDir,'out_minstat.wav'), y_min/max(abs(y_min)), fs);
audiowrite(fullfile(dataDir,'out_fir.wav'), y_fir/max(abs(y_fir)), fs);

%% ---------------------------
%% 7. Results & Summary
%% ---------------------------
fprintf('\n--- RESULTS (Scale-Invariant SNR) ---\n');
fprintf('Noisy Input:         %.2f dB\n', snr_before);
fprintf('Spectral Subtract:   %.2f dB\n', snr_sub);
fprintf('Wiener Filter:       %.2f dB\n', snr_wiener);
fprintf('Min Statistics:      %.2f dB\n', snr_min);
fprintf('FIR Filter:          %.2f dB\n', snr_fir);

fid = fopen(fullfile(resultsDir,'audio_summary.txt'),'w');
fprintf(fid, 'Results (SI-SNR):\nNoisy: %.2f\nSpecSub: %.2f\nWiener: %.2f\nMinStat: %.2f\nFIR: %.2f\n', ...
    snr_before, snr_sub, snr_wiener, snr_min, snr_fir);
fclose(fid);

%% ---------------------------
%% 8. Visualization
%% ---------------------------
hf = figure('Visible','on','Position',[100 100 1000 600]);
subplot(2,1,1); 
spectrogram(x_noisy(1:L), winLen, hop, nfft, fs, 'yaxis');
title('Noisy Input Spectrogram'); caxis([-120 -20]);
subplot(2,1,2); 
spectrogram(y_wiener(1:L), winLen, hop, nfft, fs, 'yaxis');
title('Wiener Filter Output'); caxis([-120 -20]);
saveas(hf, fullfile(figDir,'spectrogram_comparison.png'));

%% ---------------------------
%% Helper Functions
%% ---------------------------
function S = my_stft(sig, win, hop, nfft)
    sig = [sig; zeros(nfft,1)]; % Pad
    winLen = length(win);
    numFrames = floor((length(sig) - winLen)/hop);
    S = zeros(nfft, numFrames);
    for k = 1:numFrames
        idx = (k-1)*hop + (1:winLen);
        S(:,k) = fft(sig(idx) .* win, nfft);
    end
end

function y = my_istft(S, win, hop, nfft)
    winLen = length(win);
    numFrames = size(S,2);
    L_out = (numFrames-1)*hop + winLen;
    y = zeros(L_out,1);
    W0 = zeros(L_out,1);
    for k = 1:numFrames
        idx = (k-1)*hop + (1:winLen);
        frame = real(ifft(S(:,k), nfft));
        y(idx) = y(idx) + frame(1:winLen); % Simple overlap-add
        % Note: For perfect reconstruction, we usually divide by sum of windows
        % But for enhancement, simple OLA is often sufficient if window is COLA compliant.
        % Here we rely on the SNR metric scaling to fix amplitude issues.
    end
end

function si_snr = compute_si_snr(clean, estimated)
    % Scale-Invariant SNR (SI-SNR)
    % This finds the best scaling factor alpha such that alpha*est matches clean
    % It removes volume differences from the error metric.
    
    % Ensure column vectors
    clean = clean(:); estimated = estimated(:);
    
    % 1. Optimal scaling (regression)
    alpha = (clean' * estimated) / (estimated' * estimated + eps);
    target = alpha * estimated;
    
    % 2. Error noise
    noise = clean - target;
    
    % 3. Calculate Ratio
    power_signal = sum(clean.^2);
    power_error = sum(noise.^2);
    si_snr = 10*log10(power_signal / (power_error + eps));
end