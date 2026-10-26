# kee / xesrevinu fork notes

Fork of [XueshiQiao/AnyDrag](https://github.com/XueshiQiao/AnyDrag) with Move fixed for
Electron / Pake / GPUI windows (Grok Bot, Multica, Zed Preview, …) where the
stock **title-bar event rewrite** path reports a drag but the window never
moves — and rewriting `event.location` yanks the system cursor to the
synthetic aim point.

## What changed

| Area | Behavior |
|------|----------|
| **Default Move (`AnyDragMoveTransport=auto`)** | Accessibility `kAXPosition` writes (events swallowed; cursor not rewritten). Temporarily clears `AXEnhancedUserInterface` around mutations. |
| **Opt-in `titleBar`** | Classic AnyDrag synthesis; warps the cursor back after each rewrite. |
| **Opt-in `sls`** | Experimental `SLSMoveWindowWithGroup` (SIP-off). Works from a normal process **outside** a `CGEventTap`; inside the tap it often returns success with a silent no-op — prefer AX. |
| **#60 / #64** | Title-bar edge anchors + focus/exposure wait (merged from upstream PRs). |
| **⌃⌘ chord** | Synthetic title-bar clicks also strip **Command/Shift** (not only Control), so ⌃⌘ Move can start a native title-bar drag when using `titleBar` mode. |

Build / local install helper: `scripts/build-and-install-local.sh`
(ad-hoc sign; re-grant Accessibility after each install).

## Preference

```bash
defaults write me.xueshi.anydrag AnyDragMoveTransport -string auto   # or ax / titleBar / sls
defaults write me.xueshi.anydrag AnyDragModifierFlags -int 9         # ⌃⌘
```

## Upstream

Track [XueshiQiao/AnyDrag](https://github.com/XueshiQiao/AnyDrag) as `upstream`.
This fork is maintained because waiting on upstream for Electron Move is not viable
for day-to-day use of many Chromium-wrapped apps.
