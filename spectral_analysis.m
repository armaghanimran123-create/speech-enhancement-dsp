% spectral_analysis.m
% Perform FFT and Power Spectral Density (manual Welch)

[x, fs] = audioread(fullfile('data','original.wav'));
x = x(:);
N = length(x);

% FFT
X = fft(x);
f = (0:N-1)*(fs/N);
mag = abs(X)/N;

% Plot spectrum
figure;
plot(f(1:floor(N/2)), 20*log10(mag(1:floor(N/2))+eps));
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
title('Magnitude Spectrum');
saveas(gcf, fullfile('figures','magnitude_spectrum.png'));

% Manual Welch PSD
winLen = 1024;
hop = winLen/2;
w = hamming(winLen);
numSeg = floor((N - winLen)/hop) + 1;
P = zeros(winLen,1);

for k = 1:numSeg
    i = (k-1)*hop + (1:winLen);
    seg = x(i).*w;
    S = fft(seg);
    P = P + (abs(S).^2)/(sum(w.^2));
end

P = P / numSeg;
f_welch = (0:winLen-1)*(fs/winLen);

% Plot PSD
figure;
plot(f_welch(1:winLen/2), 10*log10(P(1:winLen/2)+eps));
xlabel('Frequency (Hz)'); ylabel('PSD (dB/Hz)');
title('Welch PSD (manual)');
saveas(gcf, fullfile('figures','welch_psd.png'));
