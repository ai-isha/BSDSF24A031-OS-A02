
# Feature-1 Test Cases (QA)

## Scope
Project setup, directory structure, Makefile build, starter `ls-v1.0.0` binary behavior.

## Pre-requisites
- Linux environment with `gcc`, `make`, `git`
- Repository cloned locally

---

## TC-01: Repository Naming
- **Steps:** Open GitHub repo URL.
- **Expected:** Repo name is exactly `BSDSF24A031-OS-A02` (uppercase, 0 not O).
- **Actual:** ____
- **Status:** PASS / FAIL

## TC-02: Repository Visibility
- **Steps:** Check repo visibility.
- **Expected:** Public.
- **Status:** PASS / FAIL

## TC-03: Required Directory Structure
- **Steps:** Run `ls -R` in repo root.
- **Expected:** Contains `src/`, `bin/`, `obj/`, `man/`, `Makefile`, `README.md`, `REPORT.md`.
- **Status:** PASS / FAIL

## TC-04: Starter Source File Present
- **Steps:** Run `ls src/`.
- **Expected:** Contains `ls-v1.0.0.c`.
- **Status:** PASS / FAIL

## TC-05: Makefile Builds Successfully
- **Steps:** Run `make clean && make`.
- **Expected:** No errors/warnings; `bin/ls-v1.0.0` is created.
- **Status:** PASS / FAIL

## TC-06: Executable Runs with No Arguments
- **Steps:** Run `./bin/ls-v1.0.0`.
- **Expected:** Lists files in current directory (hides dotfiles).
- **Status:** PASS / FAIL

## TC-07: Executable Runs with One Directory Argument
- **Steps:** Run `./bin/ls-v1.0.0 /etc`.
- **Expected:** Prints "Directory listing of /etc :" then contents of `/etc`.
- **Status:** PASS / FAIL

## TC-08: Executable Runs with Multiple Arguments
- **Steps:** Run `./bin/ls-v1.0.0 /etc /home`.
- **Expected:** Two listings, each prefixed with the directory header.
- **Status:** PASS / FAIL

## TC-09: Non-Existent Directory
- **Steps:** Run `./bin/ls-v1.0.0 /nope`.
- **Expected:** Error to stderr: "Cannot open directory : /nope".
- **Status:** PASS / FAIL

## TC-10: Hidden Files Are Skipped
- **Steps:** Create `.hidden` in a test dir, run lsv on it.
- **Expected:** `.hidden` is NOT listed.
- **Status:** PASS / FAIL

## TC-11: `make clean` Removes Build Artifacts
- **Steps:** Run `make clean`.
- **Expected:** `bin/` and `obj/` are emptied/removed.
- **Status:** PASS / FAIL

## TC-12: Git History Contains Initial Commit
- **Steps:** Run `git log --oneline`.
- **Expected:** Commit message: "feat: Initial project setup with starter code".
- **Status:** PASS / FAIL

