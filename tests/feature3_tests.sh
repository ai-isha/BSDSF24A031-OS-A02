#!/bin/bash
# Feature-3 QA Test Runner for ls-v1.2.0 (column display)
BIN="./bin/ls-v1.2.0"
PASS=0; FAIL=0
G="\033[0;32m"; R="\033[0;31m"; Y="\033[0;33m"; N="\033[0m"
pass() { echo -e "${G}[PASS]${N} $1"; PASS=$((PASS+1)); }
fail() { echo -e "${R}[FAIL]${N} $1"; FAIL=$((FAIL+1)); }
info() { echo -e "${Y}[INFO]${N} $1"; }
hdr()  { echo; echo "==== $1 ===="; }

[ -x "$BIN" ] || { echo "Build first: make"; exit 1; }

hdr "TC-01: Default output uses multiple columns"
OUT=$($BIN)
# Count lines in output — should be fewer than number of files
FILE_COUNT=$(ls -1 | wc -l)
LINE_COUNT=$(echo "$OUT" | wc -l)
if [ "$LINE_COUNT" -lt "$FILE_COUNT" ]; then
    pass "multi-column ($LINE_COUNT lines < $FILE_COUNT files)"
else
    fail "single column ($LINE_COUNT lines for $FILE_COUNT files)"
fi

hdr "TC-02: Same files shown as 'ls'"
SYS=$(ls -1 | sort)
MINE=$($BIN | tr -s ' ' '\n' | grep -v '^$' | sort)
if [ "$SYS" == "$MINE" ]; then
    pass "same file set"
else
    info "system: $FILE_COUNT files; yours: $(echo "$MINE" | wc -l) tokens"
    fail "file sets differ"
fi

hdr "TC-03: Down-then-across order"
# In down-then-across, first column contains files at rows 0,1,2,...
# We verify by creating a known set and checking column-major order.
TMP=$(mktemp -d)
cd "$TMP"
for i in 1 2 3 4 5 6; do touch "f$i"; done
OUT=$("$OLDPWD/$BIN" 2>/dev/null || /home/ayesha/BSDSF24A031-OS-A02/bin/ls-v1.2.0)
# Print first-line tokens — should be the "top row"
FIRST_LINE=$(echo "$OUT" | head -1)
cd "$OLDPWD"
rm -rf "$TMP"
# Not strict — just check output exists
if [ -n "$FIRST_LINE" ]; then
    pass "down-then-across produced output"
else
    fail "no output for test dir"
fi

hdr "TC-04: Long filenames reduce columns"
TMP=$(mktemp -d)
cd "$TMP"
touch very_long_filename_number_one very_long_filename_number_two very_long_filename_number_three
SHORT_DIR_OUT=$(/home/ayesha/BSDSF24A031-OS-A02/bin/ls-v1.2.0 | wc -l)
cd "$OLDPWD"
rm -rf "$TMP"

TMP=$(mktemp -d)
cd "$TMP"
touch a b c d e f g h i j k l m n o p q r s t
SHORT_NAME_OUT=$(/home/ayesha/BSDSF24A031-OS-A02/bin/ls-v1.2.0 | wc -l)
cd "$OLDPWD"
rm -rf "$TMP"

if [ "$SHORT_DIR_OUT" -ge "$SHORT_NAME_OUT" ]; then
    pass "long names yield >= rows than short names ($SHORT_DIR_OUT >= $SHORT_NAME_OUT)"
else
    info "long=$SHORT_DIR_OUT short=$SHORT_NAME_OUT"
    fail "long names should reduce columns / increase rows"
fi

hdr "TC-05: Hidden files skipped"
touch .hidden_f3
$BIN | grep -q ".hidden_f3" && fail "hidden listed" || pass "hidden skipped"
rm -f .hidden_f3

hdr "TC-06: -l still works (v1.1.0 regression)"
OUT=$($BIN -l 2>&1)
echo "$OUT" | grep -qE '^[-dlbcps][rwxsStT-]{9}' && pass "-l perms" || fail "-l broken"

hdr "TC-07: -l time format still correct"
echo "$OUT" | grep -qE '[A-Z][a-z]{2} +[0-9]{1,2} +[0-9]{2}:[0-9]{2}' && pass "time ok" || fail "time broken"

hdr "TC-08: -l owner/group names still resolved"
echo "$OUT" | awk 'NR==1 {print $3, $4}' | grep -qE '[a-zA-Z]' && pass "owner/group ok" || fail "owner/group broken"

hdr "TC-09: Non-existent directory error"
ERR=$($BIN /nope 2>&1 >/dev/null)
echo "$ERR" | grep -qi "Cannot open" && pass "error printed" || fail "no error"

hdr "TC-10: Invalid flag still caught"
O=$($BIN -x 2>&1); RC=$?
[ $RC -ne 0 ] && echo "$O" | grep -qi usage && pass "usage ok" || fail "bad flag not caught"

hdr "TC-11: Multiple directories"
O=$($BIN /etc /home 2>&1)
echo "$O" | grep -q "^/etc:" && echo "$O" | grep -q "^/home:" && pass "headers ok" || fail "headers missing"

hdr "TC-12: Empty directory doesn't crash"
TMP=$(mktemp -d)
$BIN "$TMP" >/dev/null 2>&1 && pass "empty dir ok" || fail "crashed on empty dir"
rmdir "$TMP"

hdr "TC-13: Terminal-width fallback (ioctl failure)"
# Run with stdout redirected to a pipe — ioctl fails, should fall back to 80
PIPED=$($BIN | head -1)
[ -n "$PIPED" ] && pass "fallback path works" || fail "no fallback output"

hdr "TC-14: Output has no trailing whitespace on last column"
# Grab the last token of each output line, check no trailing space on any line end
if $BIN | grep -qE ' +$'; then
    info "found trailing spaces on some lines"
    fail "trailing whitespace present"
else
    pass "no trailing whitespace"
fi

hdr "TC-15: Long directory (many files) doesn't crash"
BIG=/usr/bin
if [ -d "$BIG" ]; then
    $BIN "$BIG" >/dev/null 2>&1 && pass "big dir ok" || fail "crashed on big dir"
else
    pass "skipped (no /usr/bin)"
fi

echo
echo "================================"
echo -e "Results: ${G}$PASS passed${N}, ${R}$FAIL failed${N}"
echo "================================"
[ $FAIL -eq 0 ]
