"""생성 원본에서 메뉴용 반복 구간을 만들고 음량·경계 측정값을 기록한다."""
import hashlib
import json
from pathlib import Path
import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1] / 'assets/audio/music'


def build() -> None:
    source = ROOT / 'sources/title_theme_01.mp3'
    samples, rate = sf.read(source, always_2d=True)
    # 도입·마지막 여운을 제외하고 요청한 76 BPM의 24마디 길이를 쓴다. 실제 박자 검출은 아니다.
    start = 4.0
    bars = 24
    bpm = 76
    duration = bars * 4 * 60 / bpm
    segment = samples[int(start * rate):int((start + duration) * rate)].copy()
    segment -= np.mean(segment, axis=0)
    overlap = int(1.5 * rate)
    blend = np.linspace(0.0, 1.0, overlap)[:, None]
    blend = 0.5 - 0.5 * np.cos(np.pi * blend)
    transition = segment[-overlap:] * (1 - blend) + segment[:overlap] * blend
    # 끝이 원본 overlap-1, 시작이 원본 overlap이 되도록 붙여 샘플 불연속을 막는다.
    loop = np.concatenate([segment[overlap:-overlap], transition])
    gain = min(10 ** (-3 / 20) / np.max(np.abs(loop)), 10 ** (-20 / 20) / np.sqrt(np.mean(loop * loop)))
    loop *= gain
    output = ROOT / 'title_theme.ogg'
    sf.write(output, loop, rate, format='OGG', subtype='VORBIS')
    decoded, decoded_rate = sf.read(output, always_2d=True)
    metrics = {
        'title': '왕국의 황혼', 'source': 'sources/title_theme_01.mp3',
        'output': output.name, 'sample_rate': decoded_rate, 'channels': decoded.shape[1],
        'duration_seconds': len(decoded) / decoded_rate, 'requested_bpm': bpm,
        'source_start_seconds': start, 'source_duration_seconds': duration,
        'crossfade_seconds': overlap / rate, 'gain_db': float(20 * np.log10(gain)),
        'peak_dbfs': float(20 * np.log10(np.max(np.abs(decoded)))),
        'rms_dbfs': float(20 * np.log10(np.sqrt(np.mean(decoded ** 2)))),
        'boundary_delta': float(np.max(np.abs(decoded[-1] - decoded[0]))),
        'sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
    }
    assert np.isfinite(decoded).all() and np.max(np.abs(decoded)) < 1
    assert metrics['boundary_delta'] < 0.02
    (ROOT / 'mix.json').write_text(json.dumps(metrics, ensure_ascii=False, indent=2) + '\n')
    print('MUSIC BUILD PASS:', json.dumps(metrics, ensure_ascii=False))


if __name__ == '__main__':
    build()
