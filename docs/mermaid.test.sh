#!/usr/bin/env bash
# mermaid.test.sh — parse every ```mermaid block in the repo's Markdown with the
# real mermaid parser, so a diagram that GitHub refuses to render ("Unable to
# render rich display") fails CI instead of shipping.
#
# The classic break is an unquoted node label containing a bracket:
#   Build[... tagged '[id]']     -> parse error, got 'SQS'
#   Build["... tagged '[id]'"]   -> fine
# Quote any label carrying [ ] ( ) { } or a quote character.
#
# Run directly:  bash docs/mermaid.test.sh
# Toolchain: node + npm. mermaid/jsdom are installed into a cache dir outside
# the repo on first run. Missing toolchain or no network => SKIP locally, but
# FAIL under CI (a silent pass is how the 1.12 breakage reached main).
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
CACHE="${FLOW_MERMAID_CACHE:-${TMPDIR:-/tmp}/flow-mermaid-test}"
VERSION="${FLOW_MERMAID_VERSION:-11}"

# Strict when CI is set (GitHub Actions sets CI=true) or forced by env.
strict=0
case "${CI:-}${FLOW_MERMAID_STRICT:-}" in "") ;; *) strict=1;; esac

skip_or_fail() { # reason
    if [ "$strict" = "1" ]; then
        echo "FAIL: mermaid tests could not run under CI — $1"
        exit 1
    fi
    echo "SKIP: mermaid tests — $1"
    echo "      (CI runs them strictly; install node + npm to run locally)"
    exit 0
}

command -v node >/dev/null 2>&1 || skip_or_fail "node not found"
command -v npm  >/dev/null 2>&1 || skip_or_fail "npm not found"

# ---- toolchain (cached across runs) ----
if [ ! -d "$CACHE/node_modules/mermaid" ]; then
    mkdir -p "$CACHE" || skip_or_fail "cannot create cache dir $CACHE"
    echo "installing mermaid@$VERSION + jsdom into $CACHE (first run only)..."
    ( cd "$CACHE" \
      && npm init -y >/dev/null 2>&1 \
      && npm install --silent --no-audit --no-fund "mermaid@$VERSION" jsdom >/dev/null 2>&1 ) \
      || skip_or_fail "npm install failed (offline?)"
fi

# ---- the harness: extract every fenced block, parse each one ----
cat > "$CACHE/parse.mjs" <<'EOF'
import fs from 'fs';
import { JSDOM } from 'jsdom';

const dom = new JSDOM('<!doctype html><html><body></body></html>');
global.window = dom.window;
global.document = dom.window.document;
global.navigator = dom.window.navigator;
global.HTMLElement = dom.window.HTMLElement;

const mermaid = (await import('mermaid')).default;
mermaid.initialize({ startOnLoad: false });

// A block is the text between a ```mermaid fence and the next closing fence.
// `line` is the 1-indexed line of the block's first content line, so a failure
// points at something clickable.
function blocks(file) {
    const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
    const out = [];
    let open = false, buf = [], start = 0;
    lines.forEach((l, i) => {
        if (!open && l.trim() === '```mermaid') { open = true; buf = []; start = i + 2; return; }
        if (open && l.trim() === '```') { open = false; out.push({ file, line: start, src: buf.join('\n') }); return; }
        if (open) buf.push(l);
    });
    if (open) out.push({ file, line: start, src: buf.join('\n'), unterminated: true });
    return out;
}

let pass = 0, fail = 0;
for (const file of process.argv.slice(2)) {
    for (const b of blocks(file)) {
        const where = `${b.file}:${b.line}`;
        if (b.unterminated) { fail++; console.log(`FAIL: ${where} — unterminated \`\`\`mermaid fence`); continue; }
        try {
            await mermaid.parse(b.src);
            pass++;
        } catch (e) {
            fail++;
            const msg = String(e && e.message || e).split('\n').map(l => '      ' + l).join('\n');
            console.log(`FAIL: ${where} — mermaid.parse rejected this block\n${msg}`);
        }
    }
}

console.log(`\nmermaid: ${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
EOF

# ---- discover the Markdown to check ----
# Tracked files only (git ls-files) so scratch/vendored copies never gate CI;
# fall back to find when this isn't a git checkout.
cd "$ROOT" || exit 1
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    files=$(git ls-files '*.md')
else
    files=$(find . -name '*.md' -not -path '*/node_modules/*' -not -path './.git/*')
fi

# Only the files that actually contain a block — keeps the harness's arg list
# small and its output meaningful.
targets=""
for f in $files; do
    if grep -q '^```mermaid' "$f" 2>/dev/null; then targets="$targets $f"; fi
done

if [ -z "$targets" ]; then
    echo "mermaid: no \`\`\`mermaid blocks found — nothing to check"
    exit 0
fi

# shellcheck disable=SC2086
node "$CACHE/parse.mjs" $targets
