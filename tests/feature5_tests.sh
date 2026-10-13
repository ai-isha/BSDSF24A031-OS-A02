#!/bin/bash
# Feature-5 QA Test Runner for ls-v1.4.0 (alphabetical sort)
BIN="./bin/ls-v1.4.0"
PASS=0; FAIL=0
G="\033[0;32m"; R="\033[0;31m"; Y="\033[0;33m"; N="\033[0m"
pass() { echo -e "${G}[PASS]${N} $1"; PASS=$((PASS+1)); }
fail() { echo -e "${R}[FAIL]${N} $1"; FAIL=$((FAIL+1)); }
info() { echo -e "${Y}[INFO]${N} $1"; }
hdr()  { echo; echo "==== $1 ===="; }

[ -x "$BIN" ] || { echo "Build first: make"; exit 1; }

# Helper: extract filenames from -l output (last field per line)
get_names_via_l() { "$BIN" -l "$@" 2>/dev/null | awk '{print $NF}'; }

hdr "TC-01: -l output is alphabetically sorted"
MINE=$(get_names_via_l)
SORTED=$(echo "$MINE" | sort)
if [ "$MINE" == "$SORTED" ]; then
    pass "-l sorted alphabetically"
else
    info "got     : $(echo "$MINE" | head -3 | tr '\n' ' ')"
    info "expected: $(echo "$SORTED" | head -3 | tr '\n' ' ')"
    fail "-l NOT sorted"
fi

hdr "TC-02: -l order matches system ls -l (filenames)"
SYS=$(ls -l | awk 'NR>1 {print $NF}')
MINE=$(get_names_via_l)
if [ "$SYS" == "$MINE" ]; then
    pass "-l order identical to system ls -l"
else
    info "system first 3: $(echo "$SYS" | head -3 | tr '\n' ' ')"
    info "yours  first 3: $(echo "$MINE" | head -3 | tr '\n' ' ')"
    fail "-l order differs"
fi

hdr "TC-03: -l order matches system ls -1"
SYS=$(ls -1)
MINE=$(get_names_via_l)
if [ "$SYS" == "$MINE" ]; then
    pass "matches ls -1"
else
    fail "differs from ls -1"
fi

hdr "TC-04: /etc sorting matches system ls -1 (first 20)"
SYS=$(ls -1 /etc | head -20)
MINE=$(get_names_via_l /etc | head -20)
if [ "$SYS" == "$MINE" ]; then
    pass "/etc first 20 match"
else
    info "system: $(echo "$SYS" | head -3 | tr '\n' ' ')"
    info "yours : $(echo "$MINE" | head -3 | tr '\n' ' ')"
    fail "/etc order differs"
fi

hdr "TC-05: -x output contains same files as -l"
L_NAMES=$(get_names_via_l | sort)
X_NAMES=$("$BIN" -x | tr -s ' ' '\n' | grep -v '^$' | sort)
if [ "$L_NAMES" == "$X_NAMES" ]; then
    pass "-x same file set as -l"
else
    fail "-x file set differs"
fi

hdr "TC-06: default (column) contains same files as -l"
D_NAMES=$("$BIN" | tr -s ' ' '\n' | grep -v '^$' | sort)
L_NAMES=$(get_names_via_l | sort)
if [ "$D_NAMES" == "$L_NAMES" ]; then
    pass "default same file set as -l"
else
    fail "default file set differs"
fi

hdr "TC-07: Capital letters sort before lowercase (ASCII)"
TMP=$(mktemp -d)
touch "$TMP/apple" "$TMP/Banana" "$TMP/cherry" "$TMP/Apple" "$TMP/banana"
MINE=$(get_names_via_l "$TMP")
SORTED=$(echo "$MINE" | sort)
if [ "$MINE" == "$SORTED" ]; then
    pass "ASCII order correct"
else
    info "got: $(echo "$MINE" | tr '\n' ' ')"
    fail "case-sensitive sort wrong"
fi
rm -rf "$TMP"

hdr "TC-08: Hidden files still skipped"
touch .hidden_f5
$BIN | grep -q ".hidden_f5" && fail "hidden listed" || pass "hidden skipped"
rm -f .hidden_f5

hdr "TC-09: Empty directory doesn't crash"
TMP=$(mktemp -d)
$BIN "$TMP" >/dev/null 2>&1 && pass "empty dir ok" || fail "crashed on empty dir"
rmdir "$TMP"

hdr "TC-10: Non-existent directory error preserved"
ERR=$($BIN /nope 2>&1 >/dev/null)
echo "$ERR" | grep -qi "Cannot open" && pass "error printed" || fail "no error"

hdr "TC-11: Invalid flag still caught"
O=$($BIN -z 2>&1); RC=$?
[ $RC -ne 0 ] && echo "$O" | grep -qi usage && pass "usage ok" || fail "bad flag not caught"

hdr "TC-12: -l regression — perms column valid"
OUT=$($BIN -l | head -1)
echo "$OUT" | grep -qE '^[-dlbcps][rwxsStT-]{9}' && pass "perms ok" || fail "perms broken"

hdr "TC-13: -l time format preserved"
echo "$OUT" | grep -qE '[A-Z][a-z]{2} +[0-9]{1,2} +[0-9]{2}:[0-9]{2}' && pass "time ok" || fail "time broken"

hdr "TC-14: Multiple directories sorted (via -l)"
ETC_FIRST=$(get_names_via_l /etc | head -1)
ETC_SORTED_FIRST=$(get_names_via_l /etc | sort | head -1)
if [ "$ETC_FIRST" == "$ETC_SORTED_FIRST" ]; then
    pass "multi-dir sorted"
else
    fail "multi-dir not sorted"
fi

hdr "TC-15: Sorting does not break -x wrapping"
LINES=$($BIN -x /etc | wc -l)
if [ "$LINES" -gt 1 ]; then
    pass "-x wraps ($LINES lines)"
else
    fail "-x stopped wrapping"
fi

hdr "TC-16: -l sorted in /etc matches system (first 50)"
SYS=$(ls -l /etc | awk 'NR>1 {print $NF}' | head -50)
MINE=$(get_names_via_l /etc | head -50)
if [ "$SYS" == "$MINE" ]; then
    pass "/etc -l sorted matches system (50 items)"
else
    info "system first 3: $(echo "$SYS" | head -3 | tr '\n' ' ')"
    info "yours  first 3: $(echo "$MINE" | head -3 | tr '\n' ' ')"
    fail "/etc -l differs"
fi

echo
echo "================================"
echo -e "Results: ${G}$PASS passed${N}, ${R}$FAIL failed${N}"
echo "================================"
[ $FAIL -eq 0 ]
