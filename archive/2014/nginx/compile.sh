#!/bin/bash

#
# scoreboard.hf2.access.log = without 172.16.66
#
#
#

cat scoreboard.hf2.access.log | logstalgia -1280x720 --from '2014-11-07 10:30:00' --pitch-speed 0.1 --simulation-speed 30 --update-rate 5 --output-ppm-stream - | ffmpeg -y -r 60 -f image2pipe -vcodec ppm -i - -vcodec libx264 -preset ultrafast -pix_fmt yuv420p -crf 1 -threads 0 -bf 0 scoreboard.mp4
#logstalgia --from '2014-11-07 10:30:00' --pitch-speed 0.1 --simulation-speed 30 --update-rate 5 scoreboard.hf2.access.log
