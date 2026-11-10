# Exercise: The Health Check

Exercise code for the lesson **Exercise: The Health Check** in Bash in Depth on [ask-codey.com](https://www.ask-codey.com).

A book club's website runs on a small home server, and the club wants one command that says whether the server needs a look: how full the disk is, how much memory is left, how busy it is, and whether a service has failed. Finish `health.sh` so it prints one line for each, a warning for each problem, and an exit code that says whether all is well. A check script runs it on a pretend computer, job by job.

## Before you start

You need a terminal (Ubuntu on Linux or in WSL on Windows, or the Terminal app on a Mac) and **bats**, the tool that runs the check. If `bats --version` doesn't print a version yet, install it:

```bash
sudo apt install bats       # Ubuntu, and Ubuntu in WSL
brew install bats-core      # a Mac, with Homebrew
```

`health.sh` reads `free` and `systemctl`, which Linux and WSL have and a Mac doesn't. On a Mac, the check still works: it brings its own pretend versions.

## What's here

- `health.sh`: the health check to finish, with five jobs, each a comment that says what to read, what to print and when to warn.
- `check.bats`: the check. You don't need to change it.

## Run it

Open a terminal in this folder, then:

```bash
chmod +x health.sh
./health.sh
```

At first it prints only its first line, `Health check,` and the date and time.

## Check your work

From this folder:

```bash
bats check.bats
```

At first most checks fail: that is expected. Each job you finish turns its checks into a ✓. A failing check says which job it is, what it expected and what your script printed. The check runs your script on a pretend computer, with stand-ins for `df`, `free`, `uptime`, `nproc` and `systemctl` in a throwaway folder of its own, so it can try a full disk or a failed service without touching yours. Its last check runs `health.sh` on your own computer (it's skipped on a Mac).

## The rules

- Print each line exactly as its job's comment shows, with the same words and the same spaces after the colon.
- Each warning goes into the `warnings` list with `warnings+=("...")`, word for word as its job says. Job 5 prints them.
- The exit code is 0 when there are no warnings and 1 when there's at least one.

## Tips

- Try each reading on its own first, at the prompt: `df / | awk 'NR == 2 {print $5}'`.
- `$( )` saves a command's answer in a variable, and `(( ))` compares whole numbers: `(( disk >= 90 ))`.
- `free -m` gives memory in MB. `free -h` gives sizes such as `3.8Gi`, which `(( ))` can't count with.
- `${load%.*}` is the load with the dot and what follows cut off: `4.50` becomes `4`.
- `"${warnings[@]}"` is every warning, and `${#warnings[@]}` is how many there are.

## Hand it in

When it works, push your solution to a public repo of your own on GitHub, then paste that repo's address into **Submit your exercise** on the lesson page at [ask-codey.com](https://www.ask-codey.com). That's what completes the lesson. The lesson page shows the Git commands, step by step.
