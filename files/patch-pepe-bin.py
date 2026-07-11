#!/usr/bin/env python3
"""
PEPE CODE binary patcher for the Claude Code Bun-compiled ELF.
Applies same-length byte replacements so the file size stays identical
and offsets do not shift. Re-run after each `claude update`.
"""
import os, sys, shutil, hashlib, shutil as _sh, subprocess


def find_claude_bin() -> str:
    """Ищет реальный бинарь claude.
    Порядок:
      1. env CLAUDE_BIN если задан
      2. стандартный путь ~/.npm-global/... (текущего юзера)
      3. стандартный путь SUDO_USER (если запущено под sudo)
      4. which claude → readlink → claude.exe рядом
    """
    if os.environ.get("CLAUDE_BIN"):
        p = os.environ["CLAUDE_BIN"]
        if os.path.exists(p): return p

    def npm_bin_for(home):
        return os.path.join(home, ".npm-global/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe")

    # текущий $HOME
    p = npm_bin_for(os.path.expanduser("~"))
    if os.path.exists(p): return p

    # если запущено через sudo — попробуем HOME исходного юзера
    sudo_user = os.environ.get("SUDO_USER")
    if sudo_user:
        home = f"/home/{sudo_user}"
        p = npm_bin_for(home)
        if os.path.exists(p): return p

    # last resort — which claude
    which = _sh.which("claude")
    if which:
        real = os.path.realpath(which)
        # рядом должен лежать claude.exe (Bun-скомпилированный ELF)
        near = os.path.join(os.path.dirname(real), "claude.exe")
        if os.path.exists(near): return near
        # или сама цель — это уже claude.exe
        if os.path.basename(real) == "claude.exe": return real

    print("❌ не смог найти бинарь claude.exe."
          " Задай его вручную:\n   CLAUDE_BIN=/полный/путь/claude.exe python3 patch-pepe-bin.py",
          file=sys.stderr)
    sys.exit(1)


BIN = find_claude_bin()
# Кладём бэкап рядом с исходным .claude юзера, а не root
def home_of_owner():
    su = os.environ.get("SUDO_USER")
    return f"/home/{su}" if su else os.path.expanduser("~")

BAK = os.path.join(home_of_owner(), ".claude/claude.exe.bak")
os.makedirs(os.path.dirname(BAK), exist_ok=True)
print(f"[i] BIN = {BIN}", file=sys.stderr)
print(f"[i] BAK = {BAK}", file=sys.stderr)

# (original, replacement) — both must be the same byte length.
PATCHES = [
    (b"Welcome to Claude Code", b"Welcome to PEPE CODE!!"),
    # claude accent color in `theme: "dark"` (orange → amethyst purple, 15 chars each)
    (b"rgb(215,119,87)",        b"rgb(155,89,182)"),
    # Strip the "<hookName> says: " prefix from hook systemMessage renders
    # so our SessionStart Pepe banner appears clean. Same-length swap:
    # the two prefix children become empty strings padded with whitespace.
    (b'H.hookName," says: ",H.content',
     b'""        ,""       ,H.content'),
    # Same swap for Claude Code 2.1.197+ where the minifier renamed H→n
    (b'n.hookName," says: ",n.content',
     b'""        ,""       ,n.content'),
]

# Targeted patches: find `OLD` only after the `ANCHOR` byte sequence so we
# only touch the intended occurrence (used for `color:"error"` which appears
# in multiple mode entries — we only want to change the bypass one).
TARGETED = [
    {
        "anchor":  b'bypassPermissions:{title:"Bypass Permissions"',
        "old":     b'color:"error"',
        "new":     b'color:"green"',  # Ink built-in green; same 5-byte color name
    },
]

def ensure_backup():
    if not os.path.exists(BAK):
        shutil.copy2(BIN, BAK)
        print(f"[+] backup saved → {BAK}")
    else:
        print(f"[=] backup already at {BAK}")

def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()[:16]

def patch():
    with open(BIN, "rb") as f:
        data = bytearray(f.read())
    total = 0
    for orig, repl in PATCHES:
        if len(orig) != len(repl):
            sys.exit(f"length mismatch: {orig!r} != {repl!r}")
        count = 0
        idx = 0
        while True:
            idx = data.find(orig, idx)
            if idx < 0: break
            data[idx:idx+len(orig)] = repl
            count += 1
            idx += len(repl)
        print(f"[*] {orig.decode()!r:40s} → {repl.decode()!r}: {count} replacement(s)")
        total += count

    # ── универсальный swap для ANY minified var (H, n, s, q, ...):
    # Claude Code обновления минифицируют переменные по-новому.
    # Ищем ЛЮБУЮ 1-2 буквенную переменную X:  X.hookName," says: ",X.content
    # и заменяем на такую же длину: ""(spaces),""(spaces),X.content
    import re
    pattern = re.compile(rb'([A-Za-z][A-Za-z0-9]?)\.hookName," says: ",\1\.content')
    def replace_hookname(match):
        var = match.group(1)
        # 8 пробелов после первого ""
        # (6 + len(var)) пробелов после `,""` — чтобы длина совпала с original
        new = b'""' + b' ' * 8 + b',""' + b' ' * (6 + len(var)) + b',' + var + b'.content'
        assert len(new) == match.end() - match.start(), \
            f"length mismatch: var={var!r} new={len(new)} orig={match.end()-match.start()}"
        return new
    new_data, sub_count = pattern.subn(replace_hookname, bytes(data))
    if sub_count > 0:
        data = bytearray(new_data)
        print(f"[*] universal X.hookName pattern: {sub_count} replacement(s)")
        total += sub_count

    for t in TARGETED:
        anchor, old, new = t["anchor"], t["old"], t["new"]
        if len(old) != len(new):
            sys.exit(f"length mismatch: {old!r} != {new!r}")
        count = 0
        scan = 0
        while True:
            a = data.find(anchor, scan)
            if a < 0: break
            o = data.find(old, a + len(anchor), a + len(anchor) + 400)
            if o < 0:
                scan = a + len(anchor); continue
            data[o:o+len(old)] = new
            count += 1
            scan = o + len(new)
        print(f"[*] (after {anchor[:35].decode()!r}…) {old.decode()!r} → {new.decode()!r}: {count}")
        total += count
    if total == 0:
        print("[!] nothing replaced — already patched or strings not found")
        return False
    tmp = BIN + ".tmp"
    with open(tmp, "wb") as f:
        f.write(data)
    os.chmod(tmp, 0o755)
    os.replace(tmp, BIN)
    print(f"[+] wrote {BIN}  sha256[:16]={sha(BIN)}")
    return True

if __name__ == "__main__":
    ensure_backup()
    patch()
