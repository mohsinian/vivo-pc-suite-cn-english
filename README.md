# Vivo PC Suite 7.0.6 (CN) — English translation

Unofficial English translation of the **Chinese-market version** of vivo PC Suite
(`vivo办公套件`), verified and extended for **version 7.0.6** — the build shipped
for phones with a China ROM (OriginOS CN), which has **no in-app language
setting and no official English client**.

> **Community continuation.** This project is built on the excellent work of
> [**Lordlorio's Vivo-PC-Suite-PC-Companion-Suite-Chinese-Version-English-Translation**](https://github.com/Lordlorio/Vivo-PC-Suite-PC-Companion-Suite-Chinese-Version-English-Translation),
> which targets PC Suite 7.0.5. All core tooling, the translation pipeline and
> most patch data come from that project (MIT). This repository adapts the
> pipeline to **7.0.6** and adds ~620 new patches for strings vivo introduced
> or reverted after that release. Please star the upstream project too.

**Unofficial — not affiliated with or endorsed by vivo.**

## What is translated

Everything user-facing that could be found in the app:

- Main window: Home, Connect dialog (QR / USB), Notes, Calendar, Album, To-dos,
  Recorder, Settings, all menus, dialogs, toasts and tooltips
- **BlueLM Copilot panel**: welcome text, all ~370 cold-start suggestion chips,
  deep-thinking toggle, upload/parsing states, error messages
- Phone Mirroring window (`vivoScreen.exe`), Remote PC window (`vivoControl`)
- Backup/restore flows, AI-search error table, file-manager errors, cloud-sync
  banners, the photo-sync guide

Deliberately left untouched: internal logs, telemetry, AI prompt templates,
lunar-calendar parser tables, and the `动图_` filename prefix (a functional
live-photo marker — translating it would break detection).

## Download & install (Windows)

Get the latest release from the [Releases page](../../releases). It contains:

- `app.asar` — translated main archive (~365 MB)
- `app_vc.asar` — translated vivoControl (Remote PC) archive (~48 MB)
- `install.ps1` — one-click installer (no Python/Node needed)
- `SHA256SUMS.txt` — checksums

Steps:

1. Put `install.ps1`, `app.asar` and `app_vc.asar` in one folder.
2. Right-click `install.ps1` → **Run as administrator** (or run
   `powershell -ExecutionPolicy Bypass -File .\install.ps1` from an admin prompt).
3. The installer finds the install folder automatically, closes vivo,
   backs every original up as `.old`, installs the translated archives,
   switches the mirroring window to English, sets `config.ini` to
   `1033 / en_US` and restarts vivo PC Suite.

**Restore the original Chinese version:** run `install.ps1 -Restore` as admin.

**Notes**

- Applies to **PC Suite 7.0.6 (CN installer)**. For 7.0.5 use the
  [upstream project](https://github.com/Lordlorio/Vivo-PC-Suite-PC-Companion-Suite-Chinese-Version-English-Translation/releases).
- An official app update will overwrite the translation — re-apply after
  updating (and check for a new release here first).
- `vivoScreen.exe`'s Authenticode signature will show `HashMismatch` after
  patching — expected for any post-sign byte edit, harmless.
- The BlueLM Copilot's **chat replies** come from vivo's cloud model and may
  still be Chinese; ask it once per conversation to reply in English.
  Follow-up suggestion chips pushed per-answer are also server-side.

## How it works

PC Suite is an **Electron** app: virtually all UI code ships in `resources/app.asar`.
The translation replaces exact string spans and locale values inside the archive:

1. **Exact patches** (`patches.json`, 2168 entries): `original → English` pairs with
   occurrence counts — the build fails loudly if any string drifts.
2. **Locale injection**: keys present in `zh_CN` but missing from vivo's own
   `en_US` locale are filled from the project's translations.
3. **Layout fixes**: a few CSS overrides for longer English labels.
4. **Cloud-config gate**: vivo's servers push Chinese UI text (welcome screen,
   suggestion chips) that overrides local values at runtime. The config gate is
   patched to always use the local, translated config instead.

Nothing functional is touched: connection logic, SQL, telemetry and native
binaries stay byte-identical (except the single `zh-CN`→`en-US` locale flip in
`vivoScreen.exe`).

## Build from source

Requirements: **Python 3**, **Node.js**, and an untouched `app.asar` from a
7.0.6 CN install (your own installation provides it).

```bat
set PC_ASAR_SRC=C:\path\to\original\app.asar
set PC_ASAR_DST=C:\path\to\output\app.asar

py scripts\gen_missing_keys.py "%PC_ASAR_SRC%" .
py inject_locales.py
py apply_literals.py --apply
py mk_css_patch.py
py build_asar.py
node --check patched\dist\electron\renderer.js
py verify_asar.py "%PC_ASAR_DST%.new"
py check_newlines.py "%PC_ASAR_DST%.new"
```

`build_asar.py` writes `app.asar.new` next to `PC_ASAR_DST` and self-verifies
(header, contiguity, integrity hashes, no stray newlines). The vivoControl
archive is rebuilt analogously with `vc_unpack.py` → `vc_apply.py` →
`build_vc_asar.py` (env vars `VC_ASAR_SRC` / `VC_ASAR_DST`).

| Script | Role |
|---|---|
| `scripts/gen_missing_keys.py` | Builds `missing_keys.json` from the installed asar (zh↔en locale diff) |
| `inject_locales.py` | Fills en_US locale gaps → `locales-en_US.js.new` |
| `apply_literals.py` | Applies all 2168 patches → `patched/` (fails loudly on drift) |
| `mk_css_patch.py` | CSS overrides for longer English labels |
| `build_asar.py` | Rebuilds the archive, self-verifies |
| `verify_asar.py` / `check_newlines.py` | Final integrity gates |
| `scripts/install.ps1` | End-user installer (also handles vivoScreen + config.ini) |
| `map_en*.json`, `literals.json`, `patches_vc.json`, `skip.json` | The translation data |

## Attribution & license

- Original 7.0.5 project, tooling and translation data:
  **[Lordlorio/Vivo-PC-Suite-...-English-Translation](https://github.com/Lordlorio/Vivo-PC-Suite-PC-Companion-Suite-Chinese-Version-English-Translation)** (MIT) —
  this repository is a derivative work; the MIT license applies to everything
  inherited from it.
- 7.0.6 adaptation, new patches (rounds 1–5) and the copilot/welcome
  translation: this repository's contributors.

## Disclaimer

This project contains translation data and patching tooling only. The release
assets include a **modified copy of vivo's proprietary application archives**,
provided solely so that users who legitimately own the software can run it in
English; all rights to the original application remain with vivo. Use at your
own risk, keep your `.old` backups, and report issues in the tracker.
