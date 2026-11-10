#!/usr/bin/env bats
# Checks your health.sh by running it on a pretend computer, job by job.
# For each check, it makes its own small stand-ins for df, free, uptime, nproc
# and systemctl in a throwaway folder, so it can pretend the disk is full or a
# service has failed. Nothing on your computer is read for those checks, and
# nothing is changed. The last check runs health.sh on your real computer.
# Run it from this folder with:  bats check.bats
# You don't need to change this file.

setup() {
  script="$BATS_TEST_DIRNAME/health.sh"
  fake="$BATS_TEST_TMPDIR/pretend-computer"
  mkdir -p "$fake"
  make_pretend_commands
  # A healthy pretend computer, unless a check says otherwise:
  # the disk is 42% full, 3200 MB of 3900 MB of memory is available,
  # the load is 0.49 on 4 CPUs, and no service has failed.
  export FAKE_DISK=42 FAKE_TOTAL=3900 FAKE_AVAILABLE=3200 FAKE_LOAD=0.49 FAKE_CPUS=4 FAKE_FAILED=""
}

# Writes the pretend df, free, uptime, nproc and systemctl into $fake.
# Each prints what the real one would, with the numbers the check asks for.
make_pretend_commands() {
  cat > "$fake/df" <<'EOF'
#!/usr/bin/env bash
# The main disk is $FAKE_DISK% full.
if [[ " $* " == *" -h "* ]]; then
  echo "Filesystem      Size  Used Avail Use% Mounted on"
  printf '%-14s %5s %5s %5s %3s%% %s\n' /dev/sdb 100G "${FAKE_DISK}G" "$((100 - FAKE_DISK))G" "$FAKE_DISK" /
else
  echo "Filesystem     1K-blocks     Used Available Use% Mounted on"
  printf '%-14s %9s %9s %9s %3s%% %s\n' /dev/sdb 104857600 "$((FAKE_DISK * 1048576))" "$(((100 - FAKE_DISK) * 1048576))" "$FAKE_DISK" /
fi
EOF
  cat > "$fake/free" <<'EOF'
#!/usr/bin/env bash
# $FAKE_TOTAL MB of memory, $FAKE_AVAILABLE MB of it available.
# Like the real free: MB with -m, Mi sizes with -h, and KiB without either.
t=$FAKE_TOTAL a=$FAKE_AVAILABLE
times=1 suffix=""
case " $* " in
  *" -m "*) ;;
  *" -h "*) suffix=Mi ;;
  *) times=1024 ;;
esac
n() { echo "$(($1 * times))$suffix"; }
printf '%19s %11s %11s %11s %11s %11s\n' total used free shared buff/cache available
printf '%-7s %11s %11s %11s %11s %11s %11s\n' Mem: "$(n "$t")" "$(n "$((t - a))")" "$(n "$((a - a / 2))")" "$(n 20)" "$(n "$((a / 2))")" "$(n "$a")"
printf '%-7s %11s %11s %11s\n' Swap: "$(n 2047)" "$(n 0)" "$(n 2047)"
EOF
  cat > "$fake/uptime" <<'EOF'
#!/usr/bin/env bash
# Up for 12 days, with a 1-minute load average of $FAKE_LOAD.
if [[ "${1:-}" == "-p" ]]; then
  echo "up 1 week, 5 days, 3 hours, 56 minutes"
else
  echo " 14:33:12 up 12 days,  3:56,  1 user,  load average: ${FAKE_LOAD}, 0.80, 0.70"
fi
EOF
  cat > "$fake/nproc" <<'EOF'
#!/usr/bin/env bash
echo "$FAKE_CPUS"
EOF
  cat > "$fake/systemctl" <<'EOF'
#!/usr/bin/env bash
# Knows only one thing: the failed services, listed in $FAKE_FAILED.
if [[ " $* " != *" --failed "* && " $* " != *" --state=failed "* ]]; then
  echo "(The check's pretend systemctl only answers systemctl --failed.)" >&2
  exit 1
fi
count=0
[[ " $* " == *" --no-legend "* ]] || echo "  UNIT LOAD ACTIVE SUB DESCRIPTION"
for unit in $FAKE_FAILED; do
  count=$((count + 1))
  if [[ " $* " == *" --plain "* ]]; then
    echo "$unit loaded failed failed Book club job"
  else
    echo "● $unit loaded failed failed Book club job"
  fi
done
[[ " $* " == *" --no-legend "* ]] || printf '\n%s loaded units listed.\n' "$count"
EOF
  chmod +x "$fake"/*
}

# Runs your health.sh on the pretend computer, with bash, so it doesn't need
# chmod +x. Everything it prints lands in $output, and its exit code in $status.
check() {
  run env PATH="$fake:$PATH" bash "$script"
}

# Fails with the job's message when no line of the output matches the pattern.
expect_line() {
  if ! grep -Eq -- "$1" <<< "$output"; then
    echo "$2"
    echo "Your script printed:"
    echo "$output"
    return 1
  fi
}

# Fails with the job's message when a line of the output matches the pattern.
expect_no_line() {
  if grep -Eq -- "$1" <<< "$output"; then
    echo "$2"
    echo "Your script printed:"
    echo "$output"
    return 1
  fi
}

@test "the script is here and bash can read it" {
  if [[ ! -f "$script" ]]; then
    echo "health.sh is missing. Download the exercise again to get it back."
    return 1
  fi
  errors="$(bash -n "$script" 2>&1)" || {
    echo "bash found a mistake in health.sh before running it:"
    echo "$errors" | head -n 1
    echo "Look at the line it names. Common causes: a missing fi or done, or no space inside (( ))."
    return 1
  }
}

@test "1) the disk line" {
  check
  expect_line '^Disk: +42% of / used$' \
    "Job 1: with the disk 42% full, health.sh should print the line  Disk:    42% of / used"
}

@test "1) a disk 90% full or more gets a warning" {
  FAKE_DISK=90 check
  expect_line "^WARNING: the disk is 90% full\. Find what's filling it with du\.$" \
    "Job 1: with the disk 90% full, expected the line  WARNING: the disk is 90% full. Find what's filling it with du.  Is the test >= 90, and does the warning go into warnings+=( )?"
  FAKE_DISK=89 check
  expect_no_line '^WARNING: the disk' \
    "Job 1: with the disk 89% full, there should be no disk warning yet: the line is drawn at 90."
}

@test "2) the memory line" {
  check
  expect_line '^Memory: +3200 MB available of 3900 MB$' \
    "Job 2: with 3200 MB of 3900 MB available, health.sh should print  Memory:  3200 MB available of 3900 MB  (free -m gives MB; free -h gives sizes such as 3.8Gi)"
}

@test "2) less than 10% of memory available gets a warning" {
  FAKE_AVAILABLE=300 check
  expect_line '^WARNING: only 300 MB of memory is available\. Look for a busy program with top\.$' \
    "Job 2: with 300 MB of 3900 MB available (7%), expected  WARNING: only 300 MB of memory is available. Look for a busy program with top."
  FAKE_AVAILABLE=390 check
  expect_no_line '^WARNING: only' \
    "Job 2: with 390 MB of 3900 MB available (exactly 10%), there should be no memory warning: it's for less than 10%."
}

@test "3) the load line" {
  check
  expect_line '^Load: +0\.49 on 4 CPUs$' \
    "Job 3: with a 1-minute load of 0.49 on 4 CPUs, health.sh should print  Load:    0.49 on 4 CPUs  (cut -d, -f1 keeps the part before the first comma)"
}

@test "3) a load of one per CPU or more gets a warning" {
  FAKE_LOAD=4.50 check
  expect_line '^WARNING: the load is 4\.50 on 4 CPUs\. Look for a busy program with top\.$' \
    "Job 3: with a load of 4.50 on 4 CPUs, expected  WARNING: the load is 4.50 on 4 CPUs. Look for a busy program with top.  Compare \${load%.*} with the number of CPUs using >= in (( ))."
  FAKE_LOAD=3.99 check
  expect_no_line '^WARNING: the load' \
    "Job 3: with a load of 3.99 on 4 CPUs, there should be no load warning: its whole number, 3, is less than 4."
}

@test "4) failed services are counted" {
  check
  expect_line '^Failed services: 0$' \
    "Job 4: with no failed services, health.sh should print  Failed services: 0"
  FAKE_FAILED="bookclub-backup.service nginx.service" check
  expect_line '^Failed services: 2$' \
    "Job 4: with two failed services, health.sh should print  Failed services: 2  Did you count the names from systemctl --failed --no-legend --plain?"
}

@test "4) each failed service gets a warning" {
  FAKE_FAILED="bookclub-backup.service" check
  expect_line '^WARNING: bookclub-backup\.service has failed\. See systemctl status bookclub-backup\.service\.$' \
    "Job 4: with bookclub-backup.service failed, expected  WARNING: bookclub-backup.service has failed. See systemctl status bookclub-backup.service.  (awk '{print \$1}' picks the name; --plain leaves out the ● in front of it.)"
}

@test "5) a healthy computer: All OK. and exit code 0" {
  check
  expect_no_line '^WARNING' \
    "Job 5: the pretend computer is healthy, so there should be no WARNING lines."
  if [[ "$(tail -n 1 <<< "$output")" != "All OK." ]]; then
    echo "Job 5: with no warnings, the last line should be  All OK."
    echo "Your script printed:"
    echo "$output"
    return 1
  fi
  if [[ "$status" -ne 0 ]]; then
    echo "Job 5: with no warnings, health.sh should exit with 0 (it gave exit code $status)."
    return 1
  fi
}

@test "5) two problems: two warnings, Warnings: 2 and exit code 1" {
  FAKE_DISK=95 FAKE_FAILED="bookclub-backup.service" check
  if [[ "$(grep -c '^WARNING: ' <<< "$output")" -ne 2 ]]; then
    echo "Job 5: with the disk 95% full and one failed service, expected two lines that start  WARNING:"
    echo "Your script printed:"
    echo "$output"
    return 1
  fi
  if [[ "$(tail -n 1 <<< "$output")" != "Warnings: 2" ]]; then
    echo "Job 5: with two warnings, the last line should be  Warnings: 2"
    echo "Your script printed:"
    echo "$output"
    return 1
  fi
  if [[ "$status" -ne 1 ]]; then
    echo "Job 5: with warnings, health.sh should exit with 1 (it gave exit code $status)."
    return 1
  fi
}

@test "it runs on this computer too" {
  if [[ ! -d /run/systemd/system ]] || ! command -v free > /dev/null; then
    skip "this computer has no systemd or no free (a Mac, or WSL without systemd)"
  fi
  run bash "$script"
  if [[ "$status" -gt 1 ]]; then
    echo "On this computer, health.sh stopped with exit code $status. Run ./health.sh to see why."
    echo "It printed:"
    echo "$output"
    return 1
  fi
  for label in 'Disk:' 'Memory:' 'Load:' 'Failed services:'; do
    expect_line "^$label" "On this computer, health.sh printed no line that starts  $label"
  done
}
