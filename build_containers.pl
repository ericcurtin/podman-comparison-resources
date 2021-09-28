#!/usr/bin/perl

use strict;
use warnings;

if ($ARGV[0]) {
  if ("$ARGV[0]" eq "clean") {
    for (my $i = 0; $i < 100; ++$i) {
      qx(sudo podman rmi -f fat-fedora-$i);
      qx(sudo podman rmi -f fat-fedora-squashed-$i);
    }

    qx(sudo podman system prune -f);
  }

  print("\$ARGV[0]: '$ARGV[0]' not recognized\n");

  exit(0);
}

qx(sudo podman build -t fat-fedora .);
for (my $i = 0; $i < 100; ++$i) {
  qx(mkdir -p fat-fedora-$i && cp Dockerfile fat-fedora-$i/);
  chdir("fat-fedora-$i");
  qx(printf 'FROM fat-fedora\nRUN base64 /dev/urandom | head -c 100000000 > hello.html\n' > Dockerfile);
  qx(sudo podman build -t fat-fedora-$i .);
  chdir("-");
#  print("$i\n");
}

for (my $i = 0; $i < 100; ++$i) {
  chdir("fat-fedora-$i");
  qx(sudo podman build --squash -t fat-fedora-squashed-$i .);
  chdir("-");
#  print("$i\n");
}

#base64 /dev/urandom | head -c 100000000 > file

