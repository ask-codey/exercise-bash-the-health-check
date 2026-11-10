#!/usr/bin/env bash
# health.sh: checks this computer and says whether anything needs a look.
# Prints one line for each gauge, then a WARNING line for each problem.
# Exit code: 0 when all is OK, 1 when there's at least one warning.
set -euo pipefail

# Each problem's message goes into this list, with:  warnings+=("the message")
warnings=()

echo "Health check, $(date '+%F %H:%M')"

# 1. Disk. Read how full the main disk is, as a number without the %:
#    the fifth column of the second line of  df /  (tr -d % takes the % off).
#    Print:  Disk:    42% of / used
#    When it's 90 or more, add the warning:
#      the disk is 95% full. Find what's filling it with du.


# 2. Memory. Read the total and the available memory in MB: the second and
#    the seventh columns of the Mem: line of  free -m
#    Print:  Memory:  3200 MB available of 3900 MB
#    When less than 10% is available (available * 100 / total < 10), add:
#      only 300 MB of memory is available. Look for a busy program with top.


# 3. Load. Read the 1-minute load average, the first number after
#    "load average: " in  uptime , and the number of CPUs from  nproc
#    Print:  Load:    0.49 on 4 CPUs
#    When the load's whole number is at least the number of CPUs
#    (${load%.*} is the load with the dot and what follows cut off), add:
#      the load is 4.50 on 4 CPUs. Look for a busy program with top.


# 4. Failed services. List their names, the first column of
#      systemctl --failed --no-legend --plain
#    Print:  Failed services: 0   (how many there are)
#    For each failed service, add:
#      bookclub-backup.service has failed. See systemctl status bookclub-backup.service.


# 5. The verdict. Print each warning on its own line, starting "WARNING: ".
#    Then, with no warnings, print  All OK.  and exit with 0.
#    Otherwise print  Warnings: 2  (how many) and exit with 1.

