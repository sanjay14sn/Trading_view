const fs = require('fs');
const path = require('path');

const sampleRate = 44100;
const durationSeconds = 1.2;
const numSamples = Math.floor(sampleRate * durationSeconds);
const dataSize = numSamples * 2; // 16-bit mono

const buffer = Buffer.alloc(44 + dataSize);

// RIFF header
buffer.write('RIFF', 0);
buffer.writeUInt32LE(36 + dataSize, 4);
buffer.write('WAVE', 8);

// fmt chunk
buffer.write('fmt ', 12);
buffer.writeUInt32LE(16, 16); // Subchunk1Size
buffer.writeUInt16LE(1, 20);  // AudioFormat (PCM)
buffer.writeUInt16LE(1, 22);  // NumChannels (Mono)
buffer.writeUInt32LE(sampleRate, 24);
buffer.writeUInt32LE(sampleRate * 2, 28); // ByteRate
buffer.writeUInt16LE(2, 32);  // BlockAlign
buffer.writeUInt16LE(16, 34); // BitsPerSample

// data chunk
buffer.write('data', 36);
buffer.writeUInt32LE(dataSize, 40);

// Generate crisp dual-tone siren beep (880Hz + 1320Hz alternated)
for (let i = 0; i < numSamples; i++) {
    const t = i / sampleRate;
    // Alternating tone frequency every 0.15s
    const freq = (Math.floor(t / 0.15) % 2 === 0) ? 880 : 1320;
    const sample = Math.sin(2 * Math.PI * freq * t);
    // Envelope for soft edges
    const volume = 0.8;
    const pcmVal = Math.floor(sample * 32767 * volume);
    buffer.writeInt16LE(pcmVal, 44 + i * 2);
}

const dir = path.join(__dirname, '../mobile_app/assets/sounds');
if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
}

fs.writeFileSync(path.join(dir, 'alert.wav'), buffer);
console.log('✅ Generated alert.wav successfully at', path.join(dir, 'alert.wav'));
