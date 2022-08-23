#!/usr/bin/perl

use strict;
use warnings;

# dnf install smem curl nghttpd

sub qx_and_print {
  my $str = shift;

  $str = qx($str);
  if ($?) {
    print("$str\n");
  }

  return $str;
}

sub sys_and_print {
  my $str = shift;

  system("$str");
}

sub podman_build {
  my $img_name = shift;
  my $add_arg = shift || "";

  qx_and_print("sudo podman build $add_arg -t $img_name . 2>&1");
}

sub memory_details_ps {
  my $ps_name = shift;

  print("$ps_name breakdown of memory usage:\n");
  my $smem_out = qx_and_print("sudo smem -t -k -P ^$ps_name");
  my @lines = split(/\n/, $smem_out);
  my $out = "";
  if ($ps_name eq "nghttpd") {
    $out .= "$lines[0]\n";
  }

  $out .= $lines[-1];

  print("$out\n\n");
}

sub memory_used_free {
  my $free_line = qx(sudo free -m | grep Mem);

  return split(/\s+/, $free_line);
}

sub memory_used_smem {
  my $ker_user = qx(sudo smem -tw | grep 'kernel dynam\\|userspace\\|free mem');
  $ker_user =~ s/[[:alpha:]]//g;

  return split(/\s+/, $ker_user);
}

my @list_keys;
my %meminfo_h;

sub memory_used_meminfo() {
  open my $fh, '<', '/proc/meminfo' or die "open: $!\n";
  while (my $line = <$fh>) {
      my @spl = split(':', $line);
      my $num = $spl[1];
      if ($num =~ m/kB/) {
        $num =~ s/[[:alpha:][:space:]]//g;
        if (!exists $meminfo_h{$spl[0]}) {
          push(@list_keys, $spl[0]);
        }

        $meminfo_h{$spl[0]} = $num;
      }
  }


  if (!exists $meminfo_h{"Other"}) {
    push(@list_keys, "Other");
  }

  $meminfo_h{"Other"} = $meminfo_h{"MemTotal"} - $meminfo_h{"MemFree"} - ($meminfo_h{"AnonPages"} + $meminfo_h{"Mapped"} + $meminfo_h{"Buffers"} + $meminfo_h{"Cached"} + $meminfo_h{"SReclaimable"} + $meminfo_h{"SUnreclaim"});

  close $fh or die "close: $!\n";

  return %meminfo_h;
}

sub du_M {
  my $du_out = qx(sudo du -sBM /var/lib/containers);
  my @disk = split(/\s+/, $du_out);
  chop($disk[0]);
  return $disk[0];
}

my $cnt = 128;
my $file_siz = 8000;

sub pod_run {
  my $pod = shift;
  my $img_nam = shift;

  my $uuid = qx(uuidgen);
  chomp($uuid);
  sys_and_print("$pod run --name '$uuid' -d $img_nam nghttpd 6000 key.pem cert.pem > /dev/null");
}

sub str2file {
  my $str = shift;
  my $fn = shift;

  if ("$ARGV[1]" eq "file") {
    open my $fh, '>', $fn or die "open: $!\n";
    print($fh $str);
    close $fh or die "close: $!\n";
  }
}

sub run {
  my $pod = shift;
  my $img_pre = shift || "";

  if ($pod eq "sudo podman") {
    print("Run rootfull containers (with prefix $img_pre):\n\n");
  }
  elsif ($pod eq "podman") {
    print("Run rootless containers (with prefix $img_pre):\n\n");
  }
  else {
    print("Run processes (no containers):\n\n");
  }

  qx_and_print("sudo podman kill -a");
  qx_and_print("sudo podman stop -a");
  qx_and_print("sudo podman pod prune -f");
  qx_and_print("sudo podman container prune -f"); # takes a while
  qx_and_print("sudo podman volume prune -f");
  qx_and_print("podman kill -a");
  qx_and_print("podman stop -a");
  qx_and_print("podman pod prune -f");
  qx_and_print("podman container prune -f");
  qx_and_print("podman volume prune -f");
  qx_and_print("sudo pkill nghttpd");
  qx_and_print("sudo pkill podman");
  qx_and_print("sync; echo 3 | sudo tee /proc/sys/vm/drop_caches");
  
  my @tot_free_bef = memory_used_free();
  my @smem_bef = memory_used_smem();
  my %meminfo_bef = memory_used_meminfo();
  my $slabtop_content = qx(sudo slabtop -o -s c) . "\n";
  my $tot_bef = $smem_bef[1] + $smem_bef[4];
  printf("$cnt http servers %s\n\n", $pod ? "(each in a different container)" : "(just separate ps)");

  my $img_pre_memory_content = "";
  my $img_pre_meminfo_content = "Num ";
  for my $this_key (@list_keys) {
    if ($this_key =~ m/^(AnonPages|Mapped|Buffers|Cached|SReclaimable|SUnreclaim|Other)$/) {
      $img_pre_meminfo_content .= "$this_key ";
    }
  }

  chop($img_pre_meminfo_content);
  $img_pre_meminfo_content .= "\n";
  for (my $i = 0; $i < $cnt; ++$i) {
    my $port = 6000 + $i;
    if ($pod) {
      my $uuid = pod_run("$pod", "$img_pre-$i");
      sleep(1);
      sys_and_print("$pod exec '$uuid' curl -k https://127.0.0.1:6000/hello.html > /dev/null 2>&1");
    }
    else {
      chdir("fat-fedora-$i");
      sys_and_print("nghttpd $port key.pem cert.pem &");
      chdir("..");
      sleep(1);
      sys_and_print("curl -k https://127.0.0.1:$port/hello.html > /dev/null 2>&1");
    }

    my @tot_free_aft = memory_used_free();
    my @smem_aft = memory_used_smem();
    my %meminfo_aft = memory_used_meminfo();
    my $tot_aft = $smem_aft[1] + $smem_aft[4];
    $img_pre_memory_content .= sprintf("%d %d %d %d %d %d\n", $i + 1, ($smem_aft[1] - $smem_bef[1]) / 1024, ($smem_aft[4] - $smem_bef[4]) / 1024, ($tot_aft - $tot_bef) / 1024, $tot_free_aft[2] - $tot_free_bef[2], $tot_free_aft[5] - $tot_free_bef[5]);
    $img_pre_meminfo_content .= sprintf("%d ", $i + 1);
    for my $this_key (@list_keys) {
      if ($this_key =~ m/^(AnonPages|Mapped|Buffers|Cached|SReclaimable|SUnreclaim|Other)$/) {
        $meminfo_aft{$this_key} -= $meminfo_bef{$this_key};
        $img_pre_meminfo_content .= sprintf("%d ", $meminfo_aft{$this_key} / 1024);
      }
    }

    chop($img_pre_meminfo_content);
    $img_pre_meminfo_content .= "\n";
  }

  $slabtop_content .= qx(sudo slabtop -o -s c) . "\n";
  str2file($img_pre_memory_content, "$img_pre-memory.txt");
  str2file($img_pre_meminfo_content, "$img_pre-meminfo.txt");
  str2file($slabtop_content, "$img_pre-slabtop.txt");

  #  qx(sync; echo 3 | sudo tee /proc/sys/vm/drop_caches);
  my @tot_free_aft = memory_used_free();
  my @smem_aft = memory_used_smem();
  my $tot_aft = $smem_aft[1] + $smem_aft[4];
  printf("kernel dynamic memory used (smem -tw): before: %5dM after: %5dM diff: %5dM\n", $smem_bef[1] / 1024, $smem_aft[1] / 1024, ($smem_aft[1] - $smem_bef[1]) / 1024);
  printf("userspace memory used (smem -tw):      before: %5dM after: %5dM diff: %5dM\n", $smem_bef[4] / 1024, $smem_aft[4] / 1024, ($smem_aft[4] - $smem_bef[4]) / 1024);
  #  printf("free memory (smem -tw):                before: %5dM after: %5dM diff: %5dM\n", $smem_bef[7] / 1024, $smem_aft[7] / 1024, ($smem_aft[7] - $smem_bef[7]) / 1024);
  printf("total memory used (smem -tw):          before: %5dM after: %5dM diff: %5dM\n\n", $tot_bef / 1024, $tot_aft / 1024, ($tot_aft - $tot_bef) / 1024);
  # printf("Mem: (free -m, total):                 before: %5dM after: %5dM diff: %5dM\n", $tot_free_bef[1], $tot_free_aft[1], $tot_free_aft[1] - $tot_free_bef[1]);
  printf("Mem: (free -m, used):                  before: %5dM after: %5dM diff: %5dM\n", $tot_free_bef[2], $tot_free_aft[2], $tot_free_aft[2] - $tot_free_bef[2]);
  #  printf("Mem: (free -m, free):                  before: %5dM after: %5dM diff: %5dM\n", $tot_free_bef[3], $tot_free_aft[3], $tot_free_aft[3] - $tot_free_bef[3]);
  #  printf("Mem: (free -m, share):                 before: %5dM after: %5dM diff: %5dM\n", $tot_free_bef[4], $tot_free_aft[4], $tot_free_aft[4] - $tot_free_bef[4]);
  printf("Mem: (free -m, buff/cache):            before: %5dM after: %5dM diff: %5dM\n\n", $tot_free_bef[5], $tot_free_aft[5], $tot_free_aft[5] - $tot_free_bef[5]);
  #  printf("Mem: (free -m, available):             before: %5dM after: %5dM diff: %5dM\n\n", $tot_free_bef[6], $tot_free_aft[6], $tot_free_aft[6] - $tot_free_bef[6]);

  if (!system("sudo pgrep nghttpd > /dev/null")) {
    memory_details_ps("nghttpd");
  }

  if (0 && !system("sudo pgrep podman > /dev/null")) {
    print("podman breakdown of memory usage:\n");
    sys_and_print("sudo smem -t -k -P ^podman | head -n2 | tail -n1");
  }

  if (!system("sudo pgrep conmon > /dev/null")) {
    memory_details_ps("/usr/bin/conmon");
  }

  if (!system("sudo pgrep slirp4netns > /dev/null")) {
    memory_details_ps("/usr/bin/slirp4netns");
  }

  if ($pod eq "sudo podman") {
    $pod = "sudo-podman";
  }
}

if (0) {
print("resident set size (RSS), the non\-swapped physical memory that a task has used\n\n");
print("The SIZE and RSS fields don't count some parts of a process including the
page tables, kernel stack, struct thread_info, and struct task_struct.  This
is usually at least 20\ KiB of memory that is always resident.  SIZE is the
virtual size of the process (code+\:data+\:stack)\n\n");
print("The proportional set size (PSS) of a process is the count of pages it has in\n" .
      "memory, where each page is divided by the number of processes sharing it. So if\n" .
      "a process has 1000 pages all to itself, and 1000 shared with one other process,\n" .
      "its PSS will be 1500\n\n");
print("  USS (unshared memory)\n" .
      "+ (shared memory / number of processes that share that memory)\n" .
      "--------------------------------------------------------------\n" .
      "  PSS (Proportional Set Size)\n\n");
}

if ($ARGV[0]) {
  my $not_recognized = 1;
  if ("$ARGV[0]" eq "clean" || "$ARGV[0]" eq "disk") {
    $not_recognized = 0;
    qx(sudo podman system reset -f);
  }

  if ("$ARGV[0]" eq "build" || "$ARGV[0]" eq "disk") {
    $not_recognized = 0;
    my $start_time = time();
    podman_build("fat-fedora");
    str2file(sprintf("%d\n", time() - $start_time), "fat-fedora-build-time.txt");
    my $orig_disk = du_M();
    print("container storage used before building any containers:             ${orig_disk}M\n");
    my @file_content;
    my $unsquashed_build_time_content = "";
    for (my $i = 0; $i < $cnt; ++$i) {
      qx(mkdir -p fat-fedora-$i && cp Dockerfile fat-fedora-$i/);
      chdir("fat-fedora-$i");
      qx(printf 'FROM fat-fedora\nRUN openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj '/CN=localhost' 2>&1 && echo $i\nRUN base64 /dev/urandom | head -c $file_siz > hello.html && echo $i\n' > Dockerfile);
      $start_time = time();
      podman_build("fat-fedora-$i");
      $unsquashed_build_time_content .= sprintf("%d %d\n", $i + 1, time() - $start_time);
      chdir("..");
      $file_content[0][$i] = du_M() - $orig_disk;
    }

    str2file($unsquashed_build_time_content, "fat-fedora-unsquashed-build-time.txt");
    my $du_out = du_M();
    my $new_orig_disk = $du_out;
    $du_out -= $orig_disk;
    $orig_disk = $new_orig_disk;
    print("additional container storage after building unsquashed containers: ${du_out}M\n");
    my $squashed_build_time_content = "";
    for (my $i = 0; $i < $cnt; ++$i) {
      chdir("fat-fedora-$i");
      $start_time = time();
      podman_build("fat-fedora-squashed-$i", "--squash-all");
      $squashed_build_time_content .= sprintf("%d %d\n", $i + 1, time() - $start_time);
      chdir("..");
      $file_content[1][$i] = du_M() - $orig_disk;
    }

    str2file($squashed_build_time_content, "fat-fedora-squashed-build-time.txt");
    $du_out = du_M();
    $new_orig_disk = $du_out;
    $du_out -= $orig_disk;
    $orig_disk = $new_orig_disk;
    print("additional container storage after building squashed containers:   ${du_out}M\n");
    for (my $i = 0; $i < $cnt; ++$i) {
      chdir("fat-fedora-$i");
      qx(openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj '/CN=localhost' 2>&1);
      qx(base64 /dev/urandom | head -c $file_siz > hello.html);
      chdir("..");
    }

    my $disk_content = "";
    for (my $i = 0; $i < $cnt; ++$i) {
      $disk_content .= sprintf("%d %d %d\n", $i + 1, $file_content[0][$i], $file_content[1][$i]);
    }

    str2file($disk_content, "disk.txt");
  }

  if ("$ARGV[0]" eq "memory") {
    $not_recognized = 0;
    run("");
    run("sudo podman", "fat-fedora");
    run("sudo podman", "fat-fedora-squashed");
  }

  if ($not_recognized) {
    print("\$ARGV[0]: '$ARGV[0]' not recognized\n");
  }

  exit(0);
}

