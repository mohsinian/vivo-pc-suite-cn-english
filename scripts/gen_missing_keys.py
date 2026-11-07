# -*- coding: utf-8 -*-
"""Generate missing_keys.json for inject_locales.py from the 7.0.6 asar:
keys present in zh_CN locale but absent in en_US locale, per namespace.
Usage: py -I gen_missing_keys.py <asar> <repo_dir>
"""
import json, os, re, struct, sys

sys.stdout.reconfigure(encoding='utf-8')
ASAR, REPO = sys.argv[1], sys.argv[2]

MOD_PAT = re.compile(r"(\d+):function\(e\)\{e\.exports=JSON\.parse\('((?:[^'\\]|\\.)*)'\)\}")
MAP_PAT = re.compile(r'\{("\./[A-Za-z]+\.json":\d+,?)+\}')
MAPITEM_PAT = re.compile(r'"(\./[A-Za-z]+\.json)":(\d+)')


def unescape_js(s):
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c != '\\':
            out.append(c)
            i += 1
            continue
        i += 1
        if i >= len(s):
            break
        n = s[i]
        if n == 'n':
            out.append('\n')
        elif n == 't':
            out.append('\t')
        elif n == 'r':
            out.append('\r')
        elif n == 'u':
            out.append(chr(int(s[i + 1:i + 5], 16)))
            i += 4
        else:
            out.append(n)
        i += 1
    return ''.join(out)


f = open(ASAR, 'rb')
h = f.read(16)
hs = struct.unpack('<I', h[12:16])[0]
f.seek(16)
hdr = json.loads(f.read(hs).decode('utf-8'))
base = 12 + ((4 + hs + 3) // 4 * 4)


def walk(node, path):
    for k, v in node.items():
        if isinstance(v, dict) and 'files' in v:
            for item in walk(v['files'], path + [k]):
                yield item
        elif isinstance(v, dict) and 'offset' in v:
            yield path + [k], v


entries = {'/'.join(p): m for p, m in walk(hdr['files'], [])}


def txt(name):
    m = entries[name]
    f.seek(base + int(m['offset']))
    return f.read(int(m['size'])).decode('utf-8', 'replace')


def load_locale(name):
    """Return {ns: {key: value}} from a locales-*.js bundle."""
    text = txt(name)
    best = None
    for m in MAP_PAT.finditer(text):
        items = MAPITEM_PAT.findall(m.group(0))
        if best is None or len(items) > len(best):
            best = items
    ns_to_id = {fn[2:-5]: mid for fn, mid in best}
    out = {}
    for ns, mid in ns_to_id.items():
        m = re.search(re.escape(mid) + r":function\(e\)\{e\.exports=JSON\.parse\('((?:[^'\\]|\\.)*)'\)\}", text)
        if not m:
            continue
        out[ns] = json.loads(unescape_js(m.group(1)))
    return out


zh = load_locale('dist/electron/locales-zh_CN.js')
en = load_locale('dist/electron/locales-en_US.js')
print(f'zh namespaces: {len(zh)} | en namespaces: {len(en)}')

missing = {}
for ns, kv in zh.items():
    enkv = en.get(ns, {})
    for k, v in kv.items():
        if k not in enkv:
            missing[f'{ns}.{k}'] = v
print(f'missing (zh has, en lacks): {len(missing)}')

sys.path.insert(0, REPO)
import translations_en
trans = translations_en.build()
uncovered = {k: v for k, v in missing.items() if k not in trans}
covered = {k: v for k, v in missing.items() if k in trans}
print(f'covered by repo translations: {len(covered)} | UNCOVERED (stay zh): {len(uncovered)}')
with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'uncovered_keys.txt'), 'w', encoding='utf-8') as fh:
    for k, v in uncovered.items():
        fh.write(f'{k} = {v}\n')

json.dump(covered, open(os.path.join(REPO, 'missing_keys.json'), 'w', encoding='utf-8'),
          ensure_ascii=False, indent=0)
print('wrote ->', os.path.join(REPO, 'missing_keys.json'), f'({len(covered)} keys, covered-only)')
