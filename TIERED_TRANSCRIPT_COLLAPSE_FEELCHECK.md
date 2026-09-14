# Tiered transcript collapse (Wave 1) — local feel-check

Branch: `feat/tiered-transcript-collapse`

Marionette-style only. No upstream PR until this feel-check passes.

## Rebuild

From the repo root (always the built binary, never PATH `fx`):

```bash
zig build -Doptimize=ReleaseSafe
./zig-out/bin/fx
```

## Three visually distinct levels (`[` / `]`)

Composer must be empty. Keys step the preferred/live tool turn:

| Level | Hotkey path | What you should see |
| --- | --- | --- |
| **1. Full collapse** | `[` from partial/full | `▶ Tool activity · N` only (T0 umbrella) |
| **2. Partial** | `]` from collapse, or `[` from details | `▼ Tool activity · N` + one or more `● N tool calls · …` headers |
| **3. Full details** | `]` `]` from collapse | Same as 2 **plus** stock-style `├` / `└` individual tool rows |

If you only ever see the umbrella open/close with `●` summaries and never `├`/`└`, level 3 is broken.

`Enter` / `Space` (Space only while streaming) still toggles T0 for the preferred turn.

## Mid-stream hotkeys

`[` / `]` apply on the **next paint** while `• Thinking` / Generating / streaming — they must not wait for turn idle. Composer-empty gate still applies (drafting `[`/`]` types normally).

## No snap-to-bottom

Scroll up to inspect history, then hit `[` or `]`. The viewport must **preserve** its scroll anchor (no jump to composer/tail).

## Sticky umbrella / no duplicate lines

Sticky chrome and the scrolling body must not both show the same T0/T1 header rows.
When sticky is active, the in-flow umbrella drops those chrome lines.

Historical turns without the preferred key keep stock (non-umbrella) grouping — `use_umbrella` requires interleaved prose **or** the live/preferred `turn_key`, not merely a non-null collapse tree. That stops scroll-up duplication of umbrella chrome on older chat. (body keeps `├`/`└` details + prose only). Scrolling older chat must not reveal duplicated umbrella lines.

## Sticky umbrella

While a live/preferred tool turn has an umbrella:

- The **T0 header** is pinned at the **top of the transcript viewport**.
- When partially/fully expanded, **T0 + compact T1 headers** stay sticky; individual `├`/`└` detail rows and streamed prose scroll in the main body underneath.
- Tools remain grouped under that sticky umbrella even after you scroll past where the tools originally appeared.
- When there are no tools / no preferred turn, no sticky chrome.

Choice documented: sticky = T0 always; when expanded, T0 + compact T1 headers only (details stay in the scrolling body so the sticky region cannot eat the whole viewport).

## Expected live layout (level 3)

```
▼ Tool activity · N tool calls     ← sticky T0
  ● … tool call summary            ← sticky T1 header(s)
  ├ …                              ← scrolls in body
  └ …
assistant prose stream…            ← protected continuous class beneath
```

## Suggested try path

1. `zig build -Doptimize=ReleaseSafe && ./zig-out/bin/fx`
2. Optionally enable **Collapse tool calls** in settings (T1 default = headers).
3. Run a prompt that interleaves many tools and long prose.
4. Confirm sticky umbrella stays at top while prose streams.
5. Clear composer; press `]` then `]` mid-run — confirm headers then `├`/`└` details.
6. Press `[` / `[` back to full collapse.
7. Scroll up, hit a hotkey — confirm no snap to bottom.
8. `Ctrl+O` still opens full detail.

## Deferred (not this wave)

- Transcript row-focus `j`/`k` with ←/→ / `h`/`l` level walks
- Mouse targets
- Durable journal / swarm
- TTFT branches (separate)
- Steer-while-busy / Puppetmaster
