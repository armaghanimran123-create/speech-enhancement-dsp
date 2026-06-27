% filtering_analysis.m
% FIR and IIR filter design & application

[x, fs] = audioread(fullfile('data','original.wav'));
x = x(:);

%% Step 1: Add synthetic noise (white + low-frequency drift)
t = (0:length(x)-1)/fs;
noise = 0.2*randn(size(x)) + 0.1*sin(2*pi*50*t(:)); % mix of white + hum
x_noisy = x + noise;

audiowrite(fullfile('data','noisy.wav'), x_noisy, fs);

%% Step 2: FIR Bandpass Filter (e.g., 300–3400 Hz for speech)
bpFilt_FIR = designfilt('bandpassfir', ...
    'FilterOrder', 100, ...
    'CutoffFrequency1',300, ...
    'CutoffFrequency2',3400, ...
    'SampleRate',fs);

x_fir = filter(bpFilt_FIR, x_noisy);
audiowrite(fullfile('data','filtered_FIR.wav'), x_fir, fs);

%% Step 3: IIR Bandpass Filter (Butterworth)
[b,a] = butter(6, [300 3400]/(fs/2), 'bandpass');
x_iir = filter(b,a,x_noisy);
audiowrite(fullfile('data','filtered_IIR.wav'), x_iir, fs);

%% Step 4: Compare spectra
nfft = 2048;
Xo = abs(fft(x, nfft));
Xn = abs(fft(x_noisy, nfft));
Xfir = abs(fft(x_fir, nfft));
Xiir = abs(fft(x_iir, nfft));
faxis = (0:nfft-1)*(fs/nfft);

figure;
plot(faxis,20*log10(Xo+eps),'k','LineWidth',1.2); hold on;
plot(faxis,20*log10(Xn+eps),'r');
plot(faxis,20*log10(Xfir+eps),'b');
plot(faxis,20*log10(Xiir+eps),'g');
xlim([0 fs/2]);
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
legend('Original','Noisy','FIR filtered','IIR filtered');
title('Frequency-Domain Comparison');
saveas(gcf, fullfile('figures','filter_comparison.png'));

%% Step 5: Listen results (in MATLAB desktop, not online)
% sound(x,fs)
% sound(x_noisy,fs)
% sound(x_fir,fs)
% sound(x_iir,fs)
