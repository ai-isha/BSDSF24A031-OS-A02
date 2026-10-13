#!/bin/bash
BIN="./bin/ls-v1.6.0"
PASS=0; FAIL=0
G="\033[0;32m"; R="\033[0;31m"; Y="\033[0;33m"; N="\033[0m"
pass() { echo -e "${G}[PASS]${N} $1"; PASS=$((PASS+1)); }
fail() { echo -e "${R}[FAIL]${N} $1"; FAIL=$((FAIL+1)); }
info() { echo -e "${Y}[INFO]${N} $1"; }
hdr()  { echo; echo "==== $1 ===="; }

[ -x "$BIN" ] || { echo "Build first: make"; exit 1; }

ROOT=$(mktemp -d)
mkdir -p "$ROOT/a/b" "$ROOT/a/c" "$ROOT/x"
touch "$ROOT/file1.txt" "$ROOT/a/fileA.txt" "$ROOT/a/b/fileB.txt" "$ROOT/a/c/fileC.txt" "$ROOT/x/fileX.txt"

strip() { sed 's/\x1b\[[0-9;]*m//g'; }

hdr "TC-01: Without -R, only top-level listed"
OUT=$("$BIN" -l "$ROOT" | strip | tail -n +2 | awk "{print \$NF}")
if echo "$OUT" | grep -qE '(^|[[:space:]])a([[:space:]]|$)' && echo "$OUT" | grep -qE '(^|[[:space:]])x([[:space:]]|$)'; then
    pass "top-level only"
else
    info "got: $OUT"
    fail "top-level files missing"
fi

hdr "TC-02: -R prints headers for each directory"
OUT=$("$BIN" -R "$ROOT" | strip)
COUNT=$(echo "$OUT" | grep -c "^$ROOT.*:$")
if [ "$COUNT" -eq 5 ]; then pass "5 directory headers"; else info "got $COUNT"; fail "expected 5"; fi

hdr "TC-03: -R lists root first"
FIRST=$(echo "$OUT" | head -1)
if [ "$FIRST" = "$ROOT:" ]; then pass "root printed first"; else info "first: $FIRST"; fail "not first"; fi

hdr "TC-04: -R includes depth-2 file"
if echo "$OUT" | grep -q "fileB.txt"; then pass "fileB.txt present"; else fail "missing"; fi

hdr "TC-05: -R includes depth-3 file"
if echo "$OUT" | grep -q "fileC.txt"; then pass "fileC.txt present"; else fail "missing"; fi

hdr "TC-06: -R shows all 5 files"
OK=1
for f in file1.txt fileA.txt fileB.txt fileC.txt fileX.txt; do echo "$OUT" | grep -q "$f" || OK=0; done
if [ "$OK" = "1" ]; then pass "all files present"; else fail "some missing"; fi

hdr "TC-07: -lR has perms + recursion"
OUT2=$("$BIN" -lR "$ROOT" | strip)
if echo "$OUT2" | grep -qE '^[-dlbcps][rwxsStT-]{9}' && echo "$OUT2" | grep -q "$ROOT/a/b:"; then pass "-lR ok"; else fail "-lR broken"; fi

hdr "TC-08: -xR recursive headers"
OUT3=$("$BIN" -xR "$ROOT" | strip)
if echo "$OUT3" | grep -q "$ROOT/a:" && echo "$OUT3" | grep -q "$ROOT/a/b:"; then pass "-xR ok"; else fail "-xR broken"; fi

hdr "TC-09: Colors in -R"
OUTC=$("$BIN" -R "$ROOT" | cat -v)
if echo "$OUTC" | grep -q '\[0;34ma'; then pass "dir a blue"; else fail "no blue"; fi

hdr "TC-10: Sorting in recursion"
OUT4=$("$BIN" -lR "$ROOT/a" | strip | awk '/:$/{next} /^[-dl]/{print $NF}')
SORTED=$(echo "$OUT4" | sort)
if [ "$OUT4" = "$SORTED" ]; then pass "sorted"; else fail "not sorted"; fi

hdr "TC-11: Invalid flag"
O=$("$BIN" -z 2>&1); RC=$?
if [ $RC -ne 0 ] && echo "$O" | grep -qi usage; then pass "usage ok"; else fail "bad flag"; fi

hdr "TC-12: Non-existent dir"
ERR=$("$BIN" /nope 2>&1 >/dev/null)
if echo "$ERR" | grep -qi "Cannot open"; then pass "error printed"; else fail "no error"; fi

hdr "TC-13: Hidden files skipped"
touch "$ROOT/.h1" "$ROOT/a/.h2"
if "$BIN" -R "$ROOT" | grep -q "\.h1\|\.h2"; then fail "hidden listed"; else pass "hidden skipped"; fi
rm -f "$ROOT/.h1" "$ROOT/a/.h2"

hdr "TC-14: Empty dir no crash"
EMPTY=$(mktemp -d)
if "$BIN" -R "$EMPTY" >/dev/null 2>&1; then pass "ok"; else fail "crashed"; fi
rmdir "$EMPTY"

hdr "TC-15: Default multi-column"
OUT5=$("$BIN" | strip | tail -n +2)
LC=$(echo "$OUT5" | wc -l)
FC=$(ls -1 | wc -l)
if [ "$LC" -lt "$FC" ]; then pass "multi-column"; else fail "collapsed"; fi

hdr "TC-16: -l without -R"
OUT6=$("$BIN" -l | grep -E '^[-dlbcps]' | head -1 | strip)
if echo "$OUT6" | grep -qE '^[-dlbcps][rwxsStT-]{9}'; then pass "-l ok"; else fail "-l broken"; fi

rm -rf "$ROOT"

echo
echo "================================"
echo -e "Results: ${G}$PASS passed${N}, ${R}$FAIL failed${N}"
echo "================================"
[ $FAIL -eq 0 ]
