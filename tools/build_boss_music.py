"""보스전 원본의 지속 에너지·접합부를 비교해 반복용 Ogg와 편집 측정값을 만든다."""
import hashlib
import json
from pathlib import Path
import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1] / 'assets/audio/music'
BPM = 136
BEAT = 60 / BPM
BARS = 56
OVERLAP = 4 * BEAT
DURATION = BARS * 4 * BEAT


def build() -> None:
    candidates = []
    for source in sorted((ROOT / 'sources').glob('boss_theme_*.mp3')):
        samples, rate = sf.read(source, always_2d=True)
        # 도입·끝맺음을 피하고 요청한 박 간격의 후보를 비교한다. 실제 박자·조성 검출은 아니다.
        for start in np.arange(4 * BEAT, min(16.0, len(samples) / rate - DURATION - OVERLAP), BEAT):
            segment = samples[round(start * rate):round((start + DURATION + OVERLAP) * rate)].copy()
            segment -= np.mean(segment, axis=0)
            n = round(OVERLAP * rate)
            head, tail = segment[:n], segment[-n:]
            rms_head = np.sqrt(np.mean(head * head))
            rms_tail = np.sqrt(np.mean(tail * tail))
            correlation = np.mean(head * tail) / max(rms_head * rms_tail, 1e-12)
            second_rms = np.array([np.sqrt(np.mean(chunk * chunk)) for chunk in np.array_split(segment, 100)])
            dynamics = float(np.std(np.log(np.maximum(second_rms, 1e-8))))
            mismatch = abs(float(np.log(max(rms_tail, 1e-8) / max(rms_head, 1e-8))))
            score = dynamics + mismatch + 0.2 * (1 - correlation)
            candidates.append((score, source, start, dynamics, mismatch))
    assert candidates, '보스전 생성 원본이 필요합니다'
    score, source, start, dynamics, mismatch = min(candidates, key=lambda entry: entry[0])
    samples, rate = sf.read(source, always_2d=True)
    segment = samples[round(start * rate):round((start + DURATION + OVERLAP) * rate)].copy()
    segment -= np.mean(segment, axis=0)
    n = round(OVERLAP * rate)
    blend = (0.5 - 0.5 * np.cos(np.linspace(0, np.pi, n)))[:, None]
    transition = segment[-n:] * (1 - blend) + segment[:n] * blend
    loop = np.concatenate([segment[n:-n], transition])
    gain = min(10 ** (-3 / 20) / np.max(np.abs(loop)), 10 ** (-18 / 20) / np.sqrt(np.mean(loop * loop)))
    loop *= gain
    output = ROOT / 'boss_theme.ogg'
    # libsndfile의 긴 Vorbis 단일 쓰기에서 발생하는 네이티브 오류를 피한다.
    with sf.SoundFile(output, 'w', samplerate=rate, channels=loop.shape[1], format='OGG', subtype='VORBIS') as encoded:
        for offset in range(0, len(loop), 4096):
            encoded.write(loop[offset:offset + 4096])
    decoded, decoded_rate = sf.read(output, always_2d=True)
    metrics = {
        'title': '왕국의 결전', 'source': str(source.relative_to(ROOT)), 'output': output.name,
        'sample_rate': decoded_rate, 'channels': decoded.shape[1], 'duration_seconds': len(decoded) / decoded_rate,
        'requested_bpm': BPM, 'source_start_seconds': float(start),
        'source_duration_seconds': len(segment) / rate, 'crossfade_seconds': n / rate,
        'selection_score': float(score), 'window_log_rms_deviation': dynamics, 'join_log_rms_difference': mismatch,
        'candidates_checked': len(candidates), 'gain_db': float(20 * np.log10(gain)),
        'peak_dbfs': float(20 * np.log10(np.max(np.abs(decoded)))),
        'rms_dbfs': float(20 * np.log10(np.sqrt(np.mean(decoded ** 2)))),
        'boundary_delta': float(np.max(np.abs(decoded[-1] - decoded[0]))),
        'sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
    }
    assert np.isfinite(decoded).all() and np.max(np.abs(decoded)) < 1
    assert metrics['duration_seconds'] > 90 and metrics['boundary_delta'] < 0.03
    (ROOT / 'boss_mix.json').write_text(json.dumps(metrics, ensure_ascii=False, indent=2) + '\n')
    print('BOSS MUSIC BUILD PASS:', json.dumps(metrics, ensure_ascii=False))


if __name__ == '__main__':
    build()
