# Resource usage of containers (disk, memory, squashed, unsquashed)

This is a comparison of containers both squashed and unsquashed that run a http server application that serves 8K of content. We will compare running as processes, in an unsquashed container and in a squashed container.

## Base Dockerfile

The base Dockerfile from this is a fedora system with just a few small packages installed. Each container image that inherits from this uses different certificates for TLS and each image serves a unique randomly generated file of ~8K.

## Disk usage tests

These can be run via:

    ./resource_usage.pl disk file

Results (on CentOS 8 Stream):

    container storage used before building any containers:             740M
    additional container storage after building unsquashed containers: 10M
    additional container storage after building squashed containers:   91888M

## Memory usage tests

These can be run via:

    ./resource_usage.pl memory file

Results (on CentOS 8 Stream):

    Run processes (no containers): 128 http servers (just separate ps)
    
    kernel dynamic memory used (smem -tw): before:   442M after:   504M diff:    62M
    userspace memory used (smem -tw):      before:   468M after:   569M diff:   100M
    total memory used (smem -tw):          before:   911M after:  1073M diff:   162M
    
    Mem: (free -m, used):                  before:   552M after:   696M diff:   144M
    Mem: (free -m, buff/cache):            before:   345M after:   372M diff:    27M
    nghttpd breakdown of memory usage:
      PID User     Command                         Swap      USS      PSS      RSS 
      128 1                                           0   127.0M   132.8M     1.1G 
    
    Run rootfull containers (with prefix fat-fedora): 128 http servers (each in a different container)
    
    kernel dynamic memory used (smem -tw): before:   435M after:   882M diff:   447M
    userspace memory used (smem -tw):      before:   441M after:   651M diff:   209M
    total memory used (smem -tw):          before:   877M after:  1534M diff:   657M
    
    Mem: (free -m, used):                  before:   532M after:  1018M diff:   486M
    Mem: (free -m, buff/cache):            before:   335M after:   510M diff:   175M
    nghttpd breakdown of memory usage:
      PID User     Command                         Swap      USS      PSS      RSS 
      128 1                                           0    87.5M    93.1M   929.7M 
    
    /usr/bin/conmon breakdown of memory usage:
      128 1                                           0    96.4M    97.5M   346.4M 
    
    Run rootfull containers (with prefix fat-fedora-squashed): 
    128 http servers (each in a different container)
    
    kernel dynamic memory used (smem -tw): before:   475M after:  1484M diff:  1009M
    userspace memory used (smem -tw):      before:   463M after:  1497M diff:  1034M
    total memory used (smem -tw):          before:   938M after:  2982M diff:  2044M
    
    Mem: (free -m, used):                  before:   584M after:  1101M diff:   517M
    Mem: (free -m, buff/cache):            before:   344M after:  1875M diff:  1531M
    nghttpd breakdown of memory usage:
      PID User     Command                         Swap      USS      PSS      RSS 
      128 1                                           0   931.3M   931.3M   931.8M 
    
    /usr/bin/conmon breakdown of memory usage:
      128 1                                           0    96.4M    97.5M   346.4M

## Generating graphs of memory usage

These can be generated via:

    ./gnuplot.sh

after the `./resource_usage.pl memory file` command has been run. You will see
.png files output.

## Some dependencies for running script

Ensure the following is installed and in your PATH somewhere smem, slabtop,
podman, gnuplot, sudo, free, perl, just to name a few.

This script also assumes you run as a non-root user that has passwordless sudo
access.

You can run everything in one shot via:

    ./resource_usage.pl disk file && ./resource_usage.pl memory file && ./gnuplot.sh

The 128 squashed containers can take almost 100G space, beware!

## Conclusion

Unsquashed containers use around 2-3x the memory compared to just using unsandboxed processes.

Squashed containers use around 8-10x the memory compared to just using unsandboxed processes.

Squashed containers use considerably more disk space due to lack of deduplication.

