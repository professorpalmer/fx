# Tiered transcript collapse (Wave 1) — local feel-check

Branch: `feat/tiered-transcript-collapse`

Marionette-style only. No upstream PR until this feel-check passes.

## Rebuild

From the repo root (always the built binary, never PATH `fx`):

```bash
zig build
./zig-out/bin/fx
```

## Expected live layout

During a tool-heavy turn with streamed assistant text:

```
▼ Tool activity · N tool calls     ← T0 turn umbrella
  ● … tool call summary            ← T1 group header(s)
  ├ …
  └ …
assistant prose stream…            ← protected continuous class beneath
```

Not the old interleaved spam:

```
short prose
● 2 tool calls…
short prose
● 1 tool call…
```

- All tools for the turn live under one T0 umbrella.
- Assistant prose is relocated beneath the tool region (continuous), not splitting tool groups.
- With **Collapse tool calls** enabled, T1 defaults to header-only; T0 still expands to show those headers.
- `Ctrl+O` remains the full-transcript escape hatch.

## Hotkeys (composer must be empty)

| Key | Action |
| --- | --- |
| `[` | Collapse preferred turn to T0 umbrella only |
| `]` | Expand T0; keep T1 headers collapsed |
| `Enter` / `Space` (Space only while streaming) | Toggle T0 for the preferred/latest tool turn |

If the composer has any text, `[` / `]` / Space type normally.

## Suggested try path

1. `zig build && ./zig-out/bin/fx`
2. Optionally enable **Collapse tool calls** in settings (T1 default).
3. Run a prompt that interleaves tools and prose.
4. Confirm one umbrella + prose beneath (not prose/tool/prose spam).
5. Clear the composer; press `]` then `[` mid-run; confirm T0/T1 levels change without leaving the session.
6. `Ctrl+O` still opens full detail.

## Deferred (not this wave)

- Transcript row-focus `j`/`k` with ←/→ / `h`/`l` level walks
- Mouse targets
- Durable journal / swarm
- TTFT branches (separate)
- Steer-while-busy / Puppetmaster
