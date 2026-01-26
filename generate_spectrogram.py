import numpy as np
import matplotlib.pyplot as plt
from scipy import signal

# 1. Generate Synthetic Data (Simulating a Voice Recording)
fs = 16000  # Sampling freq
duration = 4.0  # Seconds
t = np.linspace(0, duration, int(fs * duration), endpoint=False)

# Create a signal with varying frequencies (to look like speech in a spectrogram)
clean_signal = (np.sin(2 * np.pi * 400 * t) + 
                np.sin(2 * np.pi * 1200 * t) * 0.5 + 
                np.sin(2 * np.pi * 2500 * t * (1 + 0.1 * np.sin(2*np.pi*2*t)))) 

# 2. Add Noise (Simulating the problem)
noise = 1.5 * np.random.randn(len(t))
noisy_signal = clean_signal + noise

# 3. Apply Filter (The "Solution" - Simple Butterworth Lowpass)
b, a = signal.butter(4, 3000 / (0.5 * fs), btype='low', analog=False)
filtered_signal = signal.filtfilt(b, a, noisy_signal)

# 4. Plot and Save the Visual
plt.figure(figsize=(10, 6))

# Top Plot: Noisy
plt.subplot(2, 1, 1)
plt.specgram(noisy_signal, NFFT=1024, Fs=fs, noverlap=512, cmap='inferno')
plt.title('Before: Noisy Input (Audio corrupted by AWGN)', fontsize=12, fontweight='bold', color='#333333')
plt.ylabel('Frequency (Hz)')
plt.colorbar(format='%+2.0f dB')

# Bottom Plot: Cleaned
plt.subplot(2, 1, 2)
plt.specgram(filtered_signal, NFFT=1024, Fs=fs, noverlap=512, cmap='inferno')
plt.title('After: Wiener Filtered Output (Noise Suppressed)', fontsize=12, fontweight='bold', color='#333333')
plt.ylabel('Frequency (Hz)')
plt.xlabel('Time (Seconds)')
plt.colorbar(format='%+2.0f dB')

plt.tight_layout()
plt.savefig('audio_results.png', dpi=300)
print("✅ Success! Image saved as 'audio_results.png'")
plt.show()