import argparse
import json
import os
import random
from dataclasses import dataclass
from typing import Dict, List, Sequence, Tuple

import librosa
import numpy as np


# Example Usage for you people who really need this 

# For easy dificulty:
# py auto_charter.py songs/Crush.mp3 charts/crush_easy.json Crush --artist Duckwrth --difficulty easy --cover-file CRUSH.jpg

@dataclass(frozen=True)
class DifficultyProfile:
    key: str
    label: str
    rating: int
    beat_division: int
    density: float
    chord_chance: float
    min_gap: float
    direction_stickiness: float
    approach_time: float


DIFFICULTY_ORDER: List[str] = ["easy", "normal", "hard", "expert"]

DIFFICULTY_PROFILES: Dict[str, DifficultyProfile] = {
    "easy": DifficultyProfile(
        key="easy",
        label="Easy",
        rating=2,
        beat_division=1,
        density=0.55,
        chord_chance=0.0,
        min_gap=0.20,
        direction_stickiness=0.65,
        approach_time=1.45,
    ),
    "normal": DifficultyProfile(
        key="normal",
        label="Normal",
        rating=3,
        beat_division=2,
        density=0.75,
        chord_chance=0.08,
        min_gap=0.12,
        direction_stickiness=0.45,
        approach_time=1.20,
    ),
    "hard": DifficultyProfile(
        key="hard",
        label="Hard",
        rating=4,
        beat_division=4,
        density=0.80,
        chord_chance=0.10,
        min_gap=0.10,
        direction_stickiness=0.30,
        approach_time=1.12,
    ),
    "expert": DifficultyProfile(
        key="expert",
        label="Expert",
        rating=5,
        beat_division=4,
        density=1.0,
        chord_chance=0.30,
        min_gap=0.06,
        direction_stickiness=0.18,
        approach_time=0.90,
    ),
}


def _scalar_tempo(tempo: np.ndarray | float) -> float:
    if isinstance(tempo, np.ndarray):
        if tempo.size == 0:
            return 120.0
        return float(tempo.reshape(-1)[0])
    return float(tempo)


def _extract_audio_features(audio_path: str) -> Tuple[np.ndarray, int, float, np.ndarray, np.ndarray, np.ndarray]:
    print(f"Loading audio from {audio_path}...")
    y, sr = librosa.load(audio_path, sr=None, mono=True)

    print("Analyzing tempo, beats, and onsets...")
    onset_env = librosa.onset.onset_strength(y=y, sr=sr)
    tempo, beat_frames = librosa.beat.beat_track(onset_envelope=onset_env, sr=sr)
    beat_times = librosa.frames_to_time(beat_frames, sr=sr)

    onset_frames = librosa.onset.onset_detect(
        onset_envelope=onset_env,
        sr=sr,
        backtrack=False,
        units="frames",
    )
    onset_times = librosa.frames_to_time(onset_frames, sr=sr)

    return y, sr, _scalar_tempo(tempo), beat_times, onset_env, onset_times


def _subdivide_beat_grid(beat_times: np.ndarray, beat_division: int) -> List[float]:
    if beat_times.size < 2:
        return []

    grid: List[float] = []
    division = max(1, beat_division)
    for i in range(len(beat_times) - 1):
        start = float(beat_times[i])
        end = float(beat_times[i + 1])
        step = (end - start) / division
        for s in range(division):
            grid.append(start + step * s)
    grid.append(float(beat_times[-1]))
    return grid


def _nearest_onset_distance(t: float, onset_times: np.ndarray) -> float:
    if onset_times.size == 0:
        return 9999.0
    idx = np.searchsorted(onset_times, t)
    best = 9999.0
    if idx < onset_times.size:
        best = abs(float(onset_times[idx]) - t)
    if idx > 0:
        best = min(best, abs(float(onset_times[idx - 1]) - t))
    return best


def _time_to_onset_strength(t: float, onset_env: np.ndarray, sr: int) -> float:
    frame = librosa.time_to_frames([t], sr=sr)
    idx = int(np.clip(frame[0], 0, max(len(onset_env) - 1, 0)))
    return float(onset_env[idx]) if onset_env.size > 0 else 0.0


def _select_directions(
    count: int,
    prev_direction: int,
    stickiness: float,
    rng: random.Random,
) -> List[int]:
    dirs = [0, 1, 2, 3]
    if count <= 0:
        return []

    if count == 1:
        if prev_direction >= 0 and rng.random() < stickiness:
            direction = (prev_direction + rng.choice([1, 3])) % 4
            return [direction]
        return [rng.choice(dirs)]

    rng.shuffle(dirs)
    chosen = dirs[:count]
    if prev_direction in chosen and rng.random() < stickiness:
        replacement_pool = [d for d in dirs if d not in chosen]
        if replacement_pool:
            chosen[chosen.index(prev_direction)] = replacement_pool[0]
    return chosen


def _build_notes_for_profile(
    profile: DifficultyProfile,
    beat_times: np.ndarray,
    onset_env: np.ndarray,
    onset_times: np.ndarray,
    sr: int,
    rng: random.Random,
) -> List[List[float | int]]:
    grid = _subdivide_beat_grid(beat_times, profile.beat_division)
    if not grid:
        return []

    max_onset = float(np.max(onset_env)) if onset_env.size > 0 else 0.0
    notes: List[List[float | int]] = []
    last_note_time = -999.0
    prev_direction = -1

    for t in grid:
        onset_strength = _time_to_onset_strength(t, onset_env, sr)
        onset_norm = (onset_strength / max_onset) if max_onset > 0.0 else 0.0
        onset_dist = _nearest_onset_distance(t, onset_times)

        # Base selection uses profile density, with boosts around actual transients.
        probability = profile.density
        if onset_dist < 0.035:
            probability += 0.22
        elif onset_dist < 0.07:
            probability += 0.10
        probability += onset_norm * 0.18
        probability = min(probability, 1.0)

        if (t - last_note_time) < profile.min_gap:
            continue

        if rng.random() > probability:
            continue

        chord_count = 1
        if rng.random() < profile.chord_chance:
            chord_count = 2 if rng.random() < 0.85 else 3

        chosen_dirs = _select_directions(chord_count, prev_direction, profile.direction_stickiness, rng)
        for direction in chosen_dirs:
            notes.append([round(float(t), 3), int(direction)])
            prev_direction = direction

        last_note_time = t

    # Ensure strict chronological order and remove duplicates.
    notes = sorted(notes, key=lambda x: (float(x[0]), int(x[1])))
    deduped: List[List[float | int]] = []
    seen = set()
    for n in notes:
        key = (n[0], n[1])
        if key not in seen:
            seen.add(key)
            deduped.append(n)
    return deduped


def _difficulty_keys_from_args(args: argparse.Namespace) -> List[str]:
    if args.difficulty_count is not None:
        count = max(1, min(args.difficulty_count, len(DIFFICULTY_ORDER)))
        return DIFFICULTY_ORDER[:count]

    if args.all_difficulties:
        return DIFFICULTY_ORDER

    return [args.difficulty]


def _derive_output_path(base_output: str, difficulty_key: str, total_difficulties: int) -> str:
    if total_difficulties == 1:
        return base_output

    root, ext = os.path.splitext(base_output)
    ext = ext or ".json"
    if root.endswith(("_easy", "_normal", "_hard", "_expert")):
        root = root.rsplit("_", 1)[0]
    return f"{root}_{difficulty_key}{ext}"


def _write_chart(
    output_path: str,
    song_name: str,
    artist: str,
    bpm: float,
    profile: DifficultyProfile,
    notes: Sequence[List[float | int]],
    audio_file: str,
    cover_file: str,
):
    chart_data = {
        "name": song_name,
        "artist": artist,
        "audio_file": audio_file,
        "cover_file": cover_file,
        "bpm": round(bpm, 2),
        "rating": profile.rating,
        "difficulty": profile.label,
        "approach_time": profile.approach_time,
        "input_offset": 0.0,
        "notes": notes,
    }

    out_dir = os.path.dirname(output_path)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(chart_data, f, indent=2)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate rhythm game charts from audio using beat and onset analysis.",
    )
    parser.add_argument("audio_file", help="Path to audio file (mp3/wav/ogg).")
    parser.add_argument("output_chart", help="Output chart path. If generating multiple difficulties, suffixes are auto-added.")
    parser.add_argument("song_name", nargs="?", default=None, help="Song display name (defaults to audio filename).")
    parser.add_argument(
        "--difficulty",
        choices=DIFFICULTY_ORDER,
        default="normal",
        help="Single difficulty profile to generate (default: normal).",
    )
    parser.add_argument(
        "--difficulty-count",
        type=int,
        default=None,
        help="Generate N progressive difficulties (easy..). Range: 1-4.",
    )
    parser.add_argument(
        "--all-difficulties",
        action="store_true",
        help="Generate easy, normal, hard, and expert charts in one run.",
    )
    parser.add_argument("--artist", default="Unknown Artist", help="Artist name to include in chart metadata.")
    parser.add_argument(
        "--audio-file",
        dest="audio_meta_file",
        default=None,
        help="Audio filename to store in chart metadata (defaults to input basename).",
    )
    parser.add_argument(
        "--cover-file",
        default="",
        help="Cover filename to store in chart metadata (example: CRUSH.jpg).",
    )
    parser.add_argument("--seed", type=int, default=1337, help="Random seed for deterministic chart output.")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if not os.path.isfile(args.audio_file):
        print(f"ERROR: Audio file not found: {args.audio_file}")
        return 1

    if args.difficulty_count is not None and args.all_difficulties:
        print("ERROR: Use either --difficulty-count or --all-difficulties, not both.")
        return 1

    song_name = args.song_name or os.path.splitext(os.path.basename(args.audio_file))[0]
    audio_file = args.audio_meta_file or os.path.basename(args.audio_file)

    _, sr, bpm, beat_times, onset_env, onset_times = _extract_audio_features(args.audio_file)
    if beat_times.size == 0:
        print("ERROR: Could not detect beats in audio. Try a clearer track or trim silence.")
        return 1

    difficulty_keys = _difficulty_keys_from_args(args)
    rng = random.Random(args.seed)

    print(f"Detected BPM: {bpm:.2f}")
    print(f"Generating difficulties: {', '.join(difficulty_keys)}")

    for difficulty_key in difficulty_keys:
        profile = DIFFICULTY_PROFILES[difficulty_key]
        notes = _build_notes_for_profile(profile, beat_times, onset_env, onset_times, sr, rng)
        output_path = _derive_output_path(args.output_chart, difficulty_key, len(difficulty_keys))
        _write_chart(output_path, song_name, args.artist, bpm, profile, notes, audio_file, args.cover_file)
        print(
            f"[{difficulty_key}] Wrote {len(notes)} notes to {output_path} "
            f"(division 1/{profile.beat_division}, density {profile.density:.2f})"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
