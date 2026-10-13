#!/bin/bash
# Feature-6 QA Test Runner for ls-v1.5.0 (colorized output)
BIN="./bin/ls-v1.5.0"
PASS=0; FAIL=0
G="\033[0;32m"; R="\033[0;31m"; Y="\033[0;33m"; N="\033[0m"
pass() { echo -e "${G}[PASS]${N} $1"; PASS=$((PASS+1)); }
fail() { echo -e "${R}[FAIL]${N} $1"; FAIL=$((FAIL+1)); }
info() { echo -e "${Y}[INFO]${N} $1"; }
hdr()  { echo; echo "==== $1 ===="; }

[ -x "$BIN" ] || { echo "Build first: make"; exit 1; }

# Setup test directory
TMP=$(mktemp -d)
touch "$TMP/regular.txt"
touch "$TMP/script.sh" && chmod +x "$TMP/script.sh"
touch "$TMP/archive.tar"
touch "$TMP/archive.zip"
touch "$TMP/bundle.gz"
mkdir "$TMP/subdir"
ln -sf /etc/hosts "$TMP/mylink"
mkfifo "$TMP/myfifo" 2>/dev/null

# Helper: capture raw ANSI output
raw() { "$BIN" "$@" | cat -v; }

hdr "TC-01: Directory is blue"
if raw "$TMP" | grep -q '\^\[\[0;34msubdir\^\[\[0m'; then
    pass "subdir colored blue"
else
    info "output: $(raw "$TMP" | head -3)"
    fail "subdir not blue"
fi

hdr "TC-02: Executable is green"
if raw "$TMP" | grep -q '\^\[\[0;32mscript.sh\^\[\[0m'; then
    pass "script.sh colored green"
else
    fail "script.sh not green"
fi

hdr "TC-03: .tar file is red"
if raw "$TMP" | grep -q '\^\[\[0;31marchive.tar\^\[\[0m'; then
    pass "archive.tar red"
else
    fail "archive.tar not red"
fi

hdr "TC-04: .zip file is red"
if raw "$TMP" | grep -q '\^\[\[0;31marchive.zip\^\[\[0m'; then
    pass "archive.zip red"
else
    fail "archive.zip not red"
fi

hdr "TC-05: .gz file is red"
if raw "$TMP" | grep -q '\^\[\[0;31mbundle.gz\^\[\[0m'; then
    pass "bundle.gz red"
else
    fail "bundle.gz not red"
fi

hdr "TC-06: Symlink is magenta/pink"
if raw "$TMP" | grep -q '\^\[\[0;35mmylink\^\[\[0m'; then
    pass "mylink magenta"
else
    fail "mylink not magenta"
fi

hdr "TC-07: FIFO is reverse video"
if raw "$TMP" | grep -q '\^\[\[7mmyfifo\^\[\[0m'; then
    pass "myfifo reverse video"
else
    fail "myfifo not reverse video"
fi

hdr "TC-08: Regular file has NO color"
if raw "$TMP" | grep -q '\^\[\[0;3[0-9]mregular.txt\^\[\[0m'; then
    fail "regular.txt wrongly colored"
else
    pass "regular.txt uncolored"
fi

hdr "TC-09: Colors present in -l mode"
if raw -l "$TMP" | grep -q '\^\[\[0;34msubdir\^\[\[0m'; then
    pass "-l colored subdir blue"
else
    fail "-l not colored"
fi

hdr "TC-10: Colors present in -x mode"
if raw -x "$TMP" | grep -q '\^\[\[0;34msubdir\^\[\[0m'; then
    pass "-x colored subdir blue"
else
    fail "-x not colored"
fi

hdr "TC-11: Every color is followed by reset code"
OUT=$(raw "$TMP")
if echo "$OUT" | grep -oE '\^\[\[[0-9;]+m' | grep -v '0m' >/dev/null; then
    pass "ANSI codes emitted"
else
    fail "no ANSI codes at all"
fi

hdr "TC-12: Alphabetical sort still works (v1.4.0 regression)"
MINE=$("$BIN" -l "$TMP" | awk '{print $NF}' | sed 's/\x1b\[[0-9;]*m//g')
SORTED=$(echo "$MINE" | sort)
if [ "$MINE" == "$SORTED" ]; then
    pass "sorted"
else
    fail "not sorted"
fi

hdr "TC-13: Hidden files still skipped"
touch "$TMP/.hidden_f6"
"$BIN" "$TMP" | grep -q ".hidden_f6" && fail "hidden listed" || pass "hidden skipped"
rm -f "$TMP/.hidden_f6"

hdr "TC-14: Non-existent directory error preserved"
ERR=$("$BIN" /nope 2>&1 >/dev/null)
echo "$ERR" | grep -qi "Cannot open" && pass "error printed" || fail "no error"

hdr "TC-15: Invalid flag still caught"
O=$("$BIN" -z 2>&1); RC=$?
[ $RC -ne 0 ] && echo "$O" | grep -qi usage && pass "usage ok" || fail "bad flag not caught"

hdr "TC-16: -l output still has perms column"
OUT=$("$BIN" -l "$TMP" | head -1 | sed 's/\x1b\[[0-9;]*m//g')
echo "$OUT" | grep -qE '^[-dlbcps][rwxsStT-]{9}' && pass "perms ok" || fail "perms broken"

rm -rf "$TMP"

echo
echo "================================"
echo -e "Results: ${G}$PASS passed${N}, ${R}$FAIL failed${N}"
echo "================================"
[ $FAIL -eq 0 ]
