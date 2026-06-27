% timefreq_analysis.m
% Short-Time Fourier Transform (manual spectrogram)

[x, fs] = audioread(fullfile('data','original.wav'));
x = x(:);

% Parameters
winLen = 1024;
hop = 256;
nfft = 1024;
win = hamming(winLen);

% Number of frames
numFrames = floor((length(x) - winLen)/hop) + 1;
S = zeros(nfft, numFrames);

% Compute STFT
for k = 1:numFrames
    idx = (k-1)*hop + (1:winLen);
    frame = x(idx) .* win;
    F = fft(frame, nfft);
    S(:,k) = F;
end

% Axes
taxis = (0:numFrames-1) * (hop/fs);
faxis = (0:nfft-1) * (fs/nfft);

% Plot spectrogram
figure;
imagesc(taxis, faxis(1:nfft/2), 20*log10(abs(S(1:nfft/2,:))+eps));
axis xy;
xlabel('Time (s)'); ylabel('Frequency (Hz)');
title('STFT Spectrogram (manual)');
colorbar;
saveas(gcf, fullfile('figures','stft_spectrogram.png'));
