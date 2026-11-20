$code = @"
using System;
using System.IO;

public class SoundSynthesizer {
    public static void SaveWav(string path, int sampleRate, float[] samples) {
        string dir = Path.GetDirectoryName(path);
        if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir)) {
            Directory.CreateDirectory(dir);
        }
        using (var fs = File.Create(path))
        using (var bw = new BinaryWriter(fs)) {
            int byteRate = sampleRate * 2;
            int dataLen = samples.Length * 2;
            bw.Write(System.Text.Encoding.ASCII.GetBytes("RIFF"));
            bw.Write(36 + dataLen);
            bw.Write(System.Text.Encoding.ASCII.GetBytes("WAVE"));
            bw.Write(System.Text.Encoding.ASCII.GetBytes("fmt "));
            bw.Write(16);
            bw.Write((short)1); // PCM
            bw.Write((short)1); // Mono
            bw.Write(sampleRate);
            bw.Write(byteRate);
            bw.Write((short)2);
            bw.Write((short)16);
            bw.Write(System.Text.Encoding.ASCII.GetBytes("data"));
            bw.Write(dataLen);
            for (int i = 0; i < samples.Length; i++) {
                float s = Math.Max(-1f, Math.Min(1f, samples[i]));
                bw.Write((short)(s * 32767));
            }
        }
    }

    public static void BuildAll(string outputDir) {
        int sr = 22050;
        Random rng = new Random(42);

        // 1. Propeller Hum (1.0 sec loopable)
        {
            float dur = 1.0f;
            int len = (int)(sr * dur);
            float[] s = new float[len];
            for (int i = 0; i < len; i++) {
                float t = (float)i / sr;
                float baseFreq = 85.0f;
                float wave = 0.45f * (float)Math.Sin(2 * Math.PI * baseFreq * t)
                           + 0.25f * (float)Math.Sin(2 * Math.PI * (baseFreq * 2) * t)
                           + 0.15f * (float)Math.Sin(2 * Math.PI * (baseFreq * 4) * t)
                           + 0.10f * ((float)rng.NextDouble() * 2f - 1f) * 0.15f;
                float chop = 0.8f + 0.2f * (float)Math.Sin(2 * Math.PI * 100 * t);
                s[i] = wave * chop * 0.4f;
            }
            SaveWav(Path.Combine(outputDir, "propeller_hum.wav"), sr, s);
        }

        // 2. Charge / Loading (2.0 sec ascending)
        {
            float dur = 2.0f;
            int len = (int)(sr * dur);
            float[] s = new float[len];
            for (int i = 0; i < len; i++) {
                float t = (float)i / sr;
                float progress = t / dur;
                float f = 280.0f + 520.0f * progress * progress;
                float trem = 0.75f + 0.25f * (float)Math.Sin(2 * Math.PI * (8 + 12 * progress) * t);
                float env = Math.Min(1.0f, t * 10f);
                s[i] = (float)Math.Sin(2 * Math.PI * f * t) * trem * env * 0.45f;
            }
            SaveWav(Path.Combine(outputDir, "charge.wav"), sr, s);
        }

        // 3. Success Ding (0.75 sec bright bell)
        {
            float dur = 0.75f;
            int len = (int)(sr * dur);
            float[] s = new float[len];
            for (int i = 0; i < len; i++) {
                float t = (float)i / sr;
                float env = (float)Math.Exp(-t * 6.5);
                float bell = 0.6f * (float)Math.Sin(2 * Math.PI * 987.77 * t)
                           + 0.35f * (float)Math.Sin(2 * Math.PI * 1975.53 * t)
                           + 0.15f * (float)Math.Sin(2 * Math.PI * 2963.30 * t);
                s[i] = bell * env * 0.55f;
            }
            SaveWav(Path.Combine(outputDir, "success_ding.wav"), sr, s);
        }

        // 4. Warning Buzz (0.28 sec double buzz)
        {
            float dur = 0.28f;
            int len = (int)(sr * dur);
            float[] s = new float[len];
            for (int i = 0; i < len; i++) {
                float t = (float)i / sr;
                bool pulse1 = (t >= 0.0f && t < 0.10f);
                bool pulse2 = (t >= 0.14f && t < 0.24f);
                if (pulse1 || pulse2) {
                    float f = 140.0f;
                    float wave = Math.Sign((float)Math.Sin(2 * Math.PI * f * t)) * 0.35f;
                    s[i] = wave;
                } else {
                    s[i] = 0f;
                }
            }
            SaveWav(Path.Combine(outputDir, "warning_buzz.wav"), sr, s);
        }

        // 5. Click (0.04 sec snappy UI tap)
        {
            float dur = 0.04f;
            int len = (int)(sr * dur);
            float[] s = new float[len];
            for (int i = 0; i < len; i++) {
                float t = (float)i / sr;
                float env = (float)Math.Exp(-t * 120.0);
                s[i] = (float)Math.Sin(2 * Math.PI * 1200 * t) * env * 0.4f;
            }
            SaveWav(Path.Combine(outputDir, "click.wav"), sr, s);
        }

        // 6. Victory Fanfare (1.8 sec)
        {
            float dur = 1.8f;
            int len = (int)(sr * dur);
            float[] s = new float[len];
            float[] noteF = { 523.25f, 659.25f, 783.99f, 1046.50f };
            float[] noteT = { 0.0f, 0.22f, 0.44f, 0.68f };
            float[] noteDur = { 0.25f, 0.25f, 0.28f, 1.10f };

            for (int i = 0; i < len; i++) {
                float t = (float)i / sr;
                float total = 0f;
                for (int n = 0; n < noteF.Length; n++) {
                    if (t >= noteT[n] && t < noteT[n] + noteDur[n]) {
                        float localT = t - noteT[n];
                        float env = (float)Math.Exp(-localT * (n == 3 ? 3.0 : 6.0));
                        float tone = (float)Math.Sin(2 * Math.PI * noteF[n] * localT) * 0.5f
                                   + (float)Math.Sin(2 * Math.PI * (noteF[n] * 2) * localT) * 0.2f;
                        total += tone * env;
                    }
                }
                s[i] = total * 0.5f;
            }
            SaveWav(Path.Combine(outputDir, "victory.wav"), sr, s);
        }

        // 7. Game Over (1.8 sec descending minor chord)
        {
            float dur = 1.8f;
            int len = (int)(sr * dur);
            float[] s = new float[len];
            float[] noteF = { 392.00f, 311.13f, 261.63f, 196.00f };
            float[] noteT = { 0.0f, 0.30f, 0.60f, 0.95f };
            float[] noteDur = { 0.35f, 0.35f, 0.40f, 0.85f };

            for (int i = 0; i < len; i++) {
                float t = (float)i / sr;
                float total = 0f;
                for (int n = 0; n < noteF.Length; n++) {
                    if (t >= noteT[n] && t < noteT[n] + noteDur[n]) {
                        float localT = t - noteT[n];
                        float env = (float)Math.Exp(-localT * (n == 3 ? 2.5 : 5.0));
                        float tone = (float)Math.Sin(2 * Math.PI * noteF[n] * localT) * 0.5f;
                        total += tone * env;
                    }
                }
                s[i] = total * 0.45f;
            }
            SaveWav(Path.Combine(outputDir, "game_over.wav"), sr, s);
        }
    }
}
"@

Add-Type -TypeDefinition $code
[SoundSynthesizer]::BuildAll("$PSScriptRoot/audio")
Get-ChildItem "$PSScriptRoot/audio" | Select-Object Name, Length
