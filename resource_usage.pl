#!/usr/bin/perl

use strict;
use warnings;

sub qx_and_print {
  my $str = shift;

#  my $tim = time();
  return qx($str);
#  printf("$str %d\n", time() - $tim);
}

sub sys_and_print {
  my $str = shift;

#  my $tim = time();
  system("$str");
#  printf("$str %d\n", time() - $tim);
}

sub memory_details_ps {
  my $ps_name = shift;

  print("$ps_name breakdown of memory usage:\n");
  my $head_tail = $ps_name eq "nghttpd" ? "head -n1; tail -n1;" : "tail -n1;";
  sys_and_print("sudo smem -t -k -P ^$ps_name | ($head_tail echo)");
}

sub memory_used_free {
  return qx_and_print("sudo free -m | grep Mem | awk '{print \$3}'");
}

sub run {
  my $pod = shift;
  my $img_pre = shift;

  if ($pod eq "sudo podman") {
    print("Running rootfull containers (with prefix $img_pre): ");
  }
  elsif ($pod eq "podman") {
    print("Running rootless containers (with prefix $img_pre): ");
  }
  else {
    print("Running processes (no containers): ");
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
#  qx_and_print("openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj '/CN=localhost' 2>&1");
#  qx_and_print("base64 /dev/urandom | head -c 100000000 > hello.html");
  qx_and_print("sync; echo 3 | sudo tee /proc/sys/vm/drop_caches");
#  print("Memory state with nothing running\n");
  
#  sys_and_print("sudo free -m | grep -v Swap; echo");
  my $tot_free_bef = memory_used_free();
  my $ker_user = qx(sudo smem -tw | grep 'kernel dynam\\|userspace');
  $ker_user =~ s/[[:alpha:]]//g;
  my @words = split(/\s+/, $ker_user);
  my $kern_bef = $words[1];
  my $user_bef = $words[4];
  my $tot_bef = $kern_bef + $user_bef;
  for (my $i = 0; $i < 100; ++$i) {
    my $port = 6000 + $i;
    if ($pod) {
      sys_and_print("$pod run --name \$(uuidgen) -d $img_pre-$i nghttpd 6000 key.pem cert.pem > /dev/null");
    }
    else {
      chdir("fat-fedora-$i");
      sys_and_print("nghttpd $port key.pem cert.pem &");
      chdir("..");
    }
  }

  printf("100 http servers %s\n\n", $pod ? "(each in a different container)" : "(just separate ps)");
#  sys_and_print("free -h; echo");
  if ($pod) {
    sys_and_print("for i in \$($pod ps -a -q); do $pod exec \$i curl -k https://127.0.0.1:6000/hello.html > /dev/null 2>&1; done");
  }
  else {
    for (my $i = 6000; $i < 6100; ++$i) {
      sys_and_print("curl -k https://127.0.0.1:$i/hello.html > /dev/null 2>&1");
    }
  }

  qx(sync; echo 3 | sudo tee /proc/sys/vm/drop_caches);
  my $tot_free_aft = memory_used_free();
  $ker_user = qx(sudo smem -tw | grep 'kernel dynam\\|userspace');
#  print("$ker_user\n");
  $ker_user =~ s/[[:alpha:]]//g;
  @words = split(/\s+/, $ker_user);
  my $kern_aft = $words[1];
  my $user_aft = $words[4];
  my $tot_aft = $kern_aft + $user_aft;

  printf("kernel dynamic memory used:   before: %4dM after: %4dM diff: %4dM\n", $kern_bef / 1024, $kern_aft / 1024, ($kern_aft - $kern_bef) / 1024);
  printf("userspace memory used:        before: %4dM after: %4dM diff: %4dM\n", $user_bef / 1024, $user_aft / 1024, ($user_aft - $user_bef) / 1024);
  printf("total memory used (smem -tw): before: %4dM after: %4dM diff: %4dM\n", $tot_bef / 1024, $tot_aft / 1024, ($tot_aft - $tot_bef) / 1024);
  printf("total memory used (free -m):  before: %4dM after: %4dM diff: %4dM\n\n", $tot_free_bef, $tot_free_aft, $tot_free_aft - $tot_free_bef);

if (0) {
  printf("kernel dynamic memory used after:  %4dM\n", $kern_aft / 1024);
  printf("userspace memory used after:  %4dM\n", $user_aft / 1024);
  printf("total memory used after:      %4dM\n\n", $tot_aft / 1024);

  printf("kernel dynamic memory used diff:   %4dM\n", ($kern_aft - $kern_bef) / 1024);
  printf("userspace memory used diff:   %4dM\n", ($user_aft - $user_bef) / 1024);
  printf("total memory used difference: %4dM\n\n", ($tot_aft - $tot_bef) / 1024);
}

#  print("'$pod' paused\n");
#  <>;
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

if (0) { 
  qx_and_print("ps axco command | sort | uniq -c | sort -nr | grep -v kworker > $pod-ps.txt");
  if ($pod) {
    print("New processes:\n");
    sys_and_print("diff -- $pod-ps.txt -ps.txt");
  }
}

#  qx($podman kill -a);
#  qx($podman stop -a);
#  qx$(podman sys_and_print prune -af);
#  qx(pkill nghttpd);
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
    qx(sudo podman rmi -f fat-fedora);
    for (my $i = 0; $i < 100; ++$i) {
      qx(sudo podman rmi -f fat-fedora-$i);
      qx(sudo podman rmi -f fat-fedora-squashed-$i);
    }

    qx(sudo podman system prune -af);
  }

  if ("$ARGV[0]" eq "build" || "$ARGV[0]" eq "disk") {
    $not_recognized = 0;
    qx(sudo podman build -t fat-fedora .);
    my $disk = qx(sudo du -sBM /var/lib/containers);
    print("container storage used before building any containers: $disk\n");
    for (my $i = 0; $i < 100; ++$i) {
      qx(mkdir -p fat-fedora-$i && cp Dockerfile fat-fedora-$i/);
      chdir("fat-fedora-$i");
      qx(printf 'FROM fat-fedora\nRUN openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj '/CN=localhost' 2>&1 && echo $i\nRUN base64 /dev/urandom | head -c 100000000 > hello.html && echo $i\n' > Dockerfile);
      qx(sudo podman build -t fat-fedora-$i .);
      chdir("..");
    }

    $disk = qx(sudo du -sBM /var/lib/containers);
    print("container storage after building unsquashed containers: $disk\n");
    for (my $i = 0; $i < 100; ++$i) {
      chdir("fat-fedora-$i");
      qx(sudo podman build --squash -t fat-fedora-squashed-$i .);
      chdir("..");
    }

    $disk = qx(sudo du -sBM /var/lib/containers);
    print("container storage after building squashed containers: $disk\n");
    for (my $i = 0; $i < 100; ++$i) {
      chdir("fat-fedora-$i");
      qx(openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj '/CN=localhost');
      qx(base64 /dev/urandom | head -c 100000000 > hello.html);
      chdir("..");
    }
  }

  if ($not_recognized) {
    print("\$ARGV[0]: '$ARGV[0]' not recognized\n");
  }

  exit(0);
}

run("");
# run("podman");
run("sudo podman", "fat-fedora");
run("sudo podman", "fat-fedora-squashed");

