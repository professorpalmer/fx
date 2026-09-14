# Tiered transcript collapse (Wave 1) — local feel-check

Branch: `feat/tiered-transcript-collapse`

Marionette-style only. No upstream PR until this feel-check passes.

## Rebuild

From the repo root (always the built binary, never PATH `fx`):

```bash
zig build -Doptimize=ReleaseSafe
./zig-out/bin/fx
```

## Expected live layout

During a tool-heavy turn with streamed assistant text:

```
▼ Tool activity · N tool calls     ← T0 turn umbrella
  ● … tool call summary            ← T1 group header(s)
  ├ …                              ← T1 details (after ] ] )
  └ …
assistant prose stream…            ← protected continuous class beneath
```

## Hotkeys (composer must be empty)

| Key | Action |
| --- | --- |
| `]` | Step expand: T0 only → T1 headers → T1 details |
| `[` | Step collapse: T1 details → T1 headers → T0 only |
| `Ctrl+O` | Full-transcript escape hatch (unchanged) |

Space and Enter are **not** collapse keys (they drive submit / streaming).

If the composer has any text, `[` / `]` type normally.

## Suggested try path

1. `zig build -Doptimize=ReleaseSafe && ./zig-out/bin/fx`
2. Run a prompt that fires many tools.
3. Clear the composer.
4. Press `]` until individual tool rows appear under the ● header.
5. Press `[` to walk back to headers, then umbrella-only.
6. `Ctrl+O` still opens full detail.

## Deferred (not this wave)

- Transcript row-focus `j`/`k` with ←/→ / `h`/`l` level walks
- Mouse targets
- Durable journal / swarm
- TTFT branches (separate)
- Steer-while-busy / Puppetmaster
