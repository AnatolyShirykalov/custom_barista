#!/usr/bin/env bash
# GPU temp + VRAM used. Replaces the nvidia_gpu block: the new driver prints temperature as a float ("34.34") and the block parses it as 0.
# Arg 1 (tests): file with the nvidia-smi csv line.
set -u
line=$( [ -n "${1:-}" ] && cat "$1" || timeout 3 nvidia-smi --query-gpu=temperature.gpu,memory.used --format=csv,noheader,nounits 2>/dev/null)
line=${line%%$'\n'*} # several GPUs: first line only
awk -F', *' -v l="$line" 'BEGIN {
  n = split(l, a, /, */)
  if (n < 2 || a[1] !~ /^[0-9.]+$/ || a[2] !~ /^[0-9.]+$/) { print "{\"icon\":\"gpu\",\"state\":\"Critical\",\"text\":\"GPU ERR\"}"; exit }
  t = int(a[1] + 0.5); st = t > 70 ? "Critical" : t > 60 ? "Warning" : "Idle"
  printf "{\"icon\":\"gpu\",\"state\":\"%s\",\"text\":\"%2d° %5dMiB\"}\n", st, t, int(a[2] + 0.5)
}'
exit 0
