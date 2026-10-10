#!/bin/sh
# Regenerate all music, stingers, SFX and voices, then check them.
# Needs: python3 + numpy + mido, fluidsynth, FluidR3_GM.sf2, ffmpeg.
# The .ogg.import files (loop flags) are kept, so Godot re-imports with loops on.
set -e
HERE="$(dirname "$0")"
python3 "$HERE/era1.py"
python3 "$HERE/stingers.py"
python3 "$HERE/title.py"
python3 "$HERE/sfx.py"
python3 "$HERE/voices.py"
python3 "$HERE/check.py"
