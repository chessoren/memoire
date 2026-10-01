#!/bin/zsh
cd "$(dirname $0)/.."
N=${1:-take}
pkill -INT -f "recordVideo" ; pkill -INT -f "record_sim demo/$N-audio.m4a"
until grep -q saved /tmp/rec-a.log 2>/dev/null; do sleep 0.2; done
until ! pgrep -f recordVideo >/dev/null; do sleep 0.2; done
sleep 1
VS=$(cat /tmp/rec-v.start); AS=$(grep audio-start /tmp/rec-a.log | awk '{print $2}')
OFF=$(python3 -c "print($AS-$VS)")
echo "offset $OFF"
scripts/.cache/mux demo/$N-video.mp4 demo/$N-audio.m4a $OFF demo/$N.mp4
