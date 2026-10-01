#!/bin/zsh
# Start silent simulator video + system audio capture. Stop with scripts/rec_stop.sh <name>
cd "$(dirname $0)/.."
ID=$(cat scripts/.cache/sim-id); N=${1:-take}
rm -f /tmp/rec-v.log /tmp/rec-a.log demo/$N-video.mp4 demo/$N-audio.m4a
scripts/.cache/record_sim demo/$N-audio.m4a > /tmp/rec-a.log 2>&1 &
xcrun simctl io $ID recordVideo --codec=h264 --force demo/$N-video.mp4 > /tmp/rec-v.log 2>&1 &
until grep -q "Recording started" /tmp/rec-v.log 2>/dev/null; do sleep 0.05; done
python3 -c "import time;print(time.time())" > /tmp/rec-v.start
# a short click so the audio stream starts immediately (trimmed by the alignment)
afplay -v 0.01 /System/Library/Sounds/Tink.aiff
echo started
