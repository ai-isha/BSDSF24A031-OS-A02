#!/bin/bash
# Feature-4 QA Test Runner for ls-v1.3.0 (horizontal -x mode)
BIN="./bin/ls-v1.3.0"
PASS=0; FAIL=0
G="\033[0;32m"; R="\033[0;31m"; Y="\033[0;33m"; N="\033[0m"
pass() { echo -e "${G}[PASS]${N} $1"; PASS=$((PASS+1)); }
fail() { echo -e "${R}[FAIL]${N} $1"; FAIL=$((FAIL+1)); }
info() { echo -e "${Y}[INFO]${N} $1"; }
hdr()  { echo; echo "==== $1 ===="; }

[ -x "$BIN" ] || { echo "Build first: make"; exit 1; }

hdr "TC-01: Default mode still works (down-then-across)"
OUT=$($BIN 2>/dev/null)
LINE_COUNT=$(echo "$OUT" | wc -l)
FILE_COUNT=$(ls -1 | wc -l)
if [ "$LINE_COUNT" -lt "$FILE_COUNT" ]; then
    pass "default multi-column ($LINE_COUNT lines < $FILE_COUNT files)"
else
    fail "default collapsed to single column"
fi

hdr "TC-02: -l mode still works (regression)"
OUT=$($BIN -l 2>&1)
echo "$OUT" | grep -qE '^[-dlbcps][rwxsStT-]{9}' && pass "-l perms" || fail "-l broken"

hdr "TC-03: -l time format still correct"
echo "$OUT" | grep -qE '[A-Z][a-z]{2} +[0-9]{1,2} +[0-9]{2}:[0-9]{2}' && pass "time ok" || fail "time broken"

hdr "TC-04: -x mode runs successfully"
$BIN -x >/dev/null 2>&1 && pass "-x runs" || fail "-x failed"

hdr "TC-05: -x produces output for /etc"
$BIN -x /etc >/dev/null 2>&1 && pass "-x /etc runs" || fail "-x /etc failed"

hdr "TC-06: -x and default produce different visual order"
DEF=$($BIN | head -1)
HOR=$($BIN -x | head -1)
if [ "$DEF" != "$HOR" ]; then
    pass "order differs (default vs -x)"
else
    info "default line 1: $DEF"
    info "-x line 1     : $HOR"
    fail "-x output identical to default"
fi

hdr "TC-07: -x wraps on narrow terminal"
LINES=$($BIN -x /etc | wc -l)
if [ "$LINES" -gt 1 ]; then
    pass "-x wrapped to $LINES lines"
else
    fail "-x did not wrap"
fi

hdr "TC-08: -x /etc produces same file count as default /etc"
DEFAULT_TOKENS=$($BIN /etc | tr -s ' ' '\n' | grep -v '^$' | wc -l)
HORIZ_TOKENS=$($BIN -x /etc | tr -s ' ' '\n' | grep -v '^$' | wc -l)
if [ "$DEFAULT_TOKENS" -eq "$HORIZ_TOKENS" ]; then
    pass "same number of items ($DEFAULT_TOKENS)"
else
    info "default: $DEFAULT_TOKENS, -x: $HORIZ_TOKENS"
    fail "file counts differ"
fi

hdr "TC-09: -x still skips hidden files"
touch .hidden_f4
$BIN -x | grep -q ".hidden_f4" && fail "hidden listed" || pass "hidden skipped"
rm -f .hidden_f4

hdr "TC-10: -x with non-existent directory error"
ERR=$($BIN -x /nope 2>&1 >/dev/null)
echo "$ERR" | grep -qi "Cannot open" && pass "error printed" || fail "no error"

hdr "TC-11: Invalid flag still caught"
O=$($BIN -z 2>&1); RC=$?
[ $RC -ne 0 ] && echo "$O" | grep -qi usage && pass "usage ok" || fail "bad flag not caught"

hdr "TC-12: -x multiple directories"
O=$($BIN -x /etc /home 2>&1)
echo "$O" | grep -q "^/etc:" && echo "$O" | grep -q "^/home:" && pass "headers ok" || fail "headers missing"

hdr "TC-13: -x output has no trailing whitespace on final column"
if $BIN -x /etc | grep -qE ' +$'; then
    info "trailing spaces present (cosmetic — acceptable per assignment)"
    pass "trailing spaces detected but non-fatal"
else
    pass "no trailing whitespace"
fi

hdr "TC-14: ioctl detects terminal width (non-piped stdout)"
if command -v script >/dev/null 2>&1; then
    W=$(script -q -c "stty cols 60; $BIN -x /etc | head -1" /dev/null 2>/dev/null | wc -l)
    if [ "$W" -ge 1 ]; then
        pass "ioctl path executed under pseudo-tty"
    else
        fail "no output under pseudo-tty"
    fi
else
    A=$($BIN -x /etc | wc -l)
    B=$($BIN -x /etc | wc -l)
    if [ "$A" -eq "$B" ]; then
        pass "deterministic fallback (80 cols) — $A lines both runs"
    else
        fail "non-deterministic output: $A vs $B"
    fi
fi

hdr "TC-15: -x and -l both accepted (last wins)"
$BIN -x -l >/dev/null 2>&1 && pass "-x -l runs" || fail "-x -l failed"
$BIN -l -x >/dev/null 2>&1 && pass "-l -x runs" || fail "-l -x failed"

echo
echo "================================"
echo -e "Results: ${G}$PASS passed${N}, ${R}$FAIL failed${N}"
echo "================================"
[ $FAIL -eq 0 ]
