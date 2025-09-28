import serial
from scipy.io.wavfile import write
import numpy as np
import time

# === Parameters ===
PORT = '/dev/ttyUSB1'        # Adjust for your system
BAUD = 460800
SAMPLE_RATE = 860            # Corrected sample rate
MAX_SAMPLES = 5000

# === Open serial port ===
ser = serial.Serial(PORT, BAUD)
print("Serial port opened.")

samples = []
start_time = time.time()

try:
    while len(samples) < MAX_SAMPLES:
        if ser.in_waiting >= 2:
            # Read two bytes: MSB first
            msb = ser.read(1)[0]
            lsb = ser.read(1)[0]
            value = (msb << 8) | lsb

            # Convert to signed
            if value >= 32768:
                value -= 65536

            samples.append(value)

            # Print sample number and value
            elapsed = time.time() - start_time
            print(f"Sample {len(samples):04d}: 0x{msb:02X} 0x{lsb:02X} → {value:6d} (Time: {elapsed:.2f} s)")

    # Convert to NumPy array
    samples_np = np.array(samples, dtype=np.float32)

    # Remove DC offset
    samples_np -= np.mean(samples_np)

    # Normalize to 16-bit PCM
    wav_data = np.int16(samples_np / np.max(np.abs(samples_np)) * 32767)

    # Save as .wav file
    write("recorded_signal.wav", SAMPLE_RATE, wav_data)
    print(f"\n✅ Saved {len(samples)} samples to 'recorded_signal.wav' at {SAMPLE_RATE} Hz")

except KeyboardInterrupt:
    print("\nInterrupted. Closing serial port.")

finally:
    ser.close()

