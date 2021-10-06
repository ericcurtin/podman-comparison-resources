#!/bin/bash
  
echo "set terminal png
set output 'podman-disk.png'
set xlabel 'Number of container images'
set ylabel 'Megabytes used on disk'

plot 'disk.txt' using 1:(\$2/1) title 'disk usage unsquashed' with lines lw 2, \
     'disk.txt' using 1:(\$3/1) title 'disk usage squashed' with lines lw 2" | gnuplot

echo "set terminal png
set output 'podman-memory.png'
set xlabel 'Number of container processes'
set ylabel 'Megabytes used in memory'

plot 'memory.txt' using 1:(\$2/1) title 'kernel dynamic memory used (smem -tw)' with lines lw 2, \
     'memory.txt' using 1:(\$3/1) title 'userspace memory used (smem -tw)' with lines lw 2, \
     'memory.txt' using 1:(\$4/1) title 'total memory used (smem -tw)' with lines lw 2, \
     'memory.txt' using 1:(\$5/1) title 'Mem: (free -m, used)' with lines lw 2, \
     'memory.txt' using 1:(\$6/1) title 'Mem: (free -m, buff/cache)' with lines lw 2" | gnuplot

