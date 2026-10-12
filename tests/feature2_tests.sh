#!/bin/bash
# Feature-2 QA Test Runner for ls-v1.1.0
# Usage: ./tests/feature2_tests.sh

BIN="./bin/ls-v1.1.0"
PASS=0
FAIL=0

# Colors
G="\033[0;32m"; R="\033[0;31m"; Y="\033[0;33m"; N="\033[0m"

pass() { echo -e "${G}[PASS]${N} $1"; PASS=$((PASS+1)); }
fail() { echo -e "${R}[FAIL]${N} $1"; FAIL=$((FAIL+1)); }
info() { echo -e "${Y}[INFO]${N} $1"; }
hdr()  { echo; echo "==== $1 ===="; }

# --- Pre-check: binary exists ---
if [ ! -x "$BIN" ]; then
    echo -e "${R}Binary $BIN not found. Run 'make' first.${N}"
    exit 1
fi

# =========================================================
hdr "TC-01: Default listing (no -l) succeeds"
if $BIN >/dev/null 2>&1; then pass "runs without error"; else fail "non-zero exit"; fi

# =========================================================
hdr "TC-02: Long listing (-l) succeeds"
OUT=$($BIN -l 2>&1)
if [ $? -eq 0 ]; then pass "-l runs"; else fail "-l failed"; fi

# =========================================================
hdr "TC-03: -l output contains permission string"
if echo "$OUT" | grep -qE '^[-dlbcps][rwxsStT-]{9}'; then
    pass "permission column looks valid"
else
    fail "no valid permission column found"
fi

# =========================================================
hdr "TC-04: -l output contains numeric link count"
if echo "$OUT" | grep -qE '^[-dlbcps][rwxsStT-]{9} +[0-9]+'; then
    pass "link count present"
else
    fail "link count missing"
fi

# =========================================================
hdr "TC-05: -l output contains human-readable owner/group (not pure digits)"
if echo "$OUT" | awk 'NR==1 {print $3, $4}' | grep -qE '[a-zA-Z]'; then
    pass "owner/group resolved to names"
else
    fail "owner/group look numeric"
fi

# =========================================================
hdr "TC-06: -l output contains time format (Mon DD HH:MM)"
if echo "$OUT" | grep -qE '[A-Z][a-z]{2} +[0-9]{1,2} +[0-9]{2}:[0-9]{2}'; then
    pass "time format correct"
else
    fail "time format wrong"
fi

# =========================================================
hdr "TC-07: Compare first 3 filenames with system ls -l"
SYS=$(ls -l | awk 'NR>1 {print $NF}' | sort)
MINE=$($BIN -l | awk '{print $NF}' | sort)
if [ "$SYS" == "$MINE" ]; then
    pass "same file set as 'ls -l'"
else
    info "system: $(echo "$SYS" | tr '\n' ' ')"
    info "yours : $(echo "$MINE" | tr '\n' ' ')"
    fail "file sets differ"
fi

# =========================================================
hdr "TC-08: Hidden files skipped"
touch .hidden_test_file
if $BIN | grep -q ".hidden_test_file"; then
    fail "hidden file listed"
else
    pass "hidden file skipped"
fi
rm -f .hidden_test_file

# =========================================================
hdr "TC-09: Multiple directories"
OUT_MULTI=$($BIN -l /etc /home 2>&1)
if echo "$OUT_MULTI" | grep -q "^/etc:" && echo "$OUT_MULTI" | grep -q "^/home:"; then
    pass "both directory headers printed"
else
    info "expected headers: /etc: and /home:"
    fail "missing directory header"
fi

# =========================================================
hdr "TC-10: Non-existent directory error to stderr"
ERR=$($BIN -l /nope 2>&1 >/dev/null)
if echo "$ERR" | grep -qi "Cannot open directory"; then
    pass "error message printed"
else
    fail "no error for missing dir"
fi

# =========================================================
hdr "TC-11: Invalid flag prints usage and exits non-zero"
OUT_X=$($BIN -x 2>&1); RC=$?
if [ $RC -ne 0 ] && echo "$OUT_X" | grep -qi "usage"; then
    pass "usage shown, exit=$RC"
else
    info "exit=$RC output=$OUT_X"
    fail "bad flag not handled"
fi

# =========================================================
# =========================================================
hdr "TC-12: setuid bit formatting"
touch suid_test
chmod 4755 suid_test
OUT_S=$($BIN -l | grep suid_test)
if echo "$OUT_S" | grep -q '^-rws'; then
    pass "setuid shown as 's'"
else
    info "got: $OUT_S"
    fail "setuid not formatted"
fi
rm -f suid_test

# =========================================================
hdr "TC-13: sticky bit on directory"
mkdir -p sticky_test
chmod 1777 sticky_test
OUT_T=$($BIN -l | grep sticky_test)
if echo "$OUT_T" | grep -q 't$'; then
    pass "sticky shown as 't'"
else
    info "got: $OUT_T"
    fail "sticky not formatted"
fi
rm -rf sticky_test

# =========================================================
echo
echo "================================"
echo -e "Results: ${G}$PASS passed${N}, ${R}$FAIL failed${N}"
echo "================================"

[ $FAIL -eq 0 ] && exit 0 || exit 1
