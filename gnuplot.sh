#!/bin/bash

#t=png # png
#t=dumb # ascii

for t in png dumb; do
  echo "set terminal $t
set output 'podman-disk.$t'
set xlabel 'Number of container images'
set ylabel 'Megabytes used on disk'

plot 'disk.txt' using 1:(\$2/1) title 'disk usage unsquashed' with lines lw 2, \
     'disk.txt' using 1:(\$3/1) title 'disk usage squashed' with lines lw 2" | gnuplot

  for i in -memory fat-fedora-memory fat-fedora-squashed-memory; do
    echo "set terminal $t
set output '$i.$t'
set xlabel 'Number of processes'
set ylabel 'Megabytes used in memory'

plot '$i.txt' using 1:(\$2/1) title 'kernel dynamic memory used (smem -tw)' with lines lw 2, \
     '$i.txt' using 1:(\$3/1) title 'userspace memory used (smem -tw)' with lines lw 2, \
     '$i.txt' using 1:(\$4/1) title 'total memory used (smem -tw)' with lines lw 2, \
     '$i.txt' using 1:(\$5/1) title 'Mem: (free -m, used)' with lines lw 2, \
     '$i.txt' using 1:(\$6/1) title 'Mem: (free -m, buff/cache)' with lines lw 2" | gnuplot
  done

  for i in -meminfo fat-fedora-meminfo fat-fedora-squashed-meminfo; do
    echo "set terminal $t
set output '$i.$t'
set xlabel 'Number of processes'
set ylabel 'Megabytes used in memory'
set key autotitle columnheader
plot for [i=2:48] '$i.txt' using 1:i with lines lw 2" | gnuplot
  done

  mv -- -memory.$t processes-memory.$t
  mv fat-fedora-memory.$t unsquashed-memory.$t
  mv fat-fedora-squashed-memory.$t squashed-memory.$t
  mv -- -meminfo.$t processes-meminfo.$t
  mv fat-fedora-meminfo.$t unsquashed-meminfo.$t
  mv fat-fedora-squashed-meminfo.$t squashed-meminfo.$t
done

