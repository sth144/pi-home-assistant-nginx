# Sports auto-tune

Wakes the TV and the NVIDIA Shield when any TeamTracker-tracked team's game goes
live, then launches whichever streaming app is carrying it.

| File | Purpose |
|---|---|
| `templates.yaml` | `sensor.live_tracked_game` — dynamic roster of in-progress games |
| `automation/sports-auto-tune.yaml` | The automation |
| `custom_templates/streaming_apps.jinja.example` | Scaffold for the network → app map |

Requires in `configuration.yaml`:

```yaml
template: !include templates.yaml
```

Adding a new top-level key needs a **full HA restart**, not a reload.

## Teams are not enumerated

The trigger watches `sensor.live_tracked_game`, which derives from
`integration_entities('teamtracker')` at render time. Adding a team to the
TeamTracker integration is enough — no edits to the automation.

## `custom_templates/streaming_apps.jinja` is NOT tracked

Gitignored, because which networks are mapped reveals which streaming services
this household subscribes to. On a fresh host:

```bash
cp custom_templates/streaming_apps.jinja.example \
   custom_templates/streaming_apps.jinja
# fill in your services, then:  action: homeassistant.reload_custom_templates
```

The automation imports it as a Jinja macro (`app_for(network)`), so a missing file
breaks the `activity` variable. It returns an Android TV package name, a deep
link, or `unsupported` (which routes to a notification instead of touching the TV).

Values were read off the Shield via `androidtv.adb_command` (`pm list packages`,
`cmd package dump`), not guessed. Two findings worth keeping: Prime Video on this
device is the Shield-specific `…livingroom.nvidia` build, and YouTube TV is
installed, making it a sound catch-all for linear channels lacking their own app.

## Guards

- **08:00–23:00 only.** Evaluated at kickoff, so a 22:45 start still fires.
- **Never interrupts.** Requires the TV to be *positively* `off`/`standby`
  (`unavailable`/`unknown` are rejected — they mean HA lost track of the TV, which
  is exactly when a hijack is most likely), plus no androidtv/ADB media_player
  `playing`/`paused`, plus no Plex playback on the Shield.

Failing safe means: if `samsungtv` goes `unavailable`, auto-tune stops firing
rather than risk hijacking a live viewing session.

## Manual testing

```yaml
action: automation.trigger
target:
  entity_id: automation.sports_auto_tune_tv_at_kickoff
data:
  variables:
    test_network: "NBC"
    test_game: "sensor.ncaaf_wisconsin_badgers"
```

Passing a network that maps to `unsupported` exercises the notify-only path
without disturbing whatever is on screen.

## Verified end to end

2026-07-28, both devices cold: TV `off`→`on` (~18s, Wake-on-LAN), Shield
`off`→`on`, `current_activity=com.peacocktv.peacockandroid`. The natural trigger
path was verified separately, including that the guard blocks while the TV is on.

Prerequisites, both on the TV:

- **It must be on the network.** It had been running headless as a display for the
  Shield. Without that, `media_player.samsung_q60aa_65_tv` reads `off` even when
  physically on — which silently disables the guard's TV check.
- **Power On with Mobile** (`General → Network → Expert Settings`) — this is what
  makes Wake-on-LAN work. `samsungtv` sends the magic packet itself; no
  `wake_on_lan:` integration needed.

## Known limitations

1. **Last mile inside the app.** Neither Peacock nor Prime publishes a deep link to
   a specific live event, so after launching the app the automation presses
   `DPAD_CENTER` once, betting the game is the focused hero tile. Usually right
   during a live window, not guaranteed. `foxsports://live` is the exception — it
   lands on live content directly.
2. **MLS / Apple TV is not automatable.** The Shield has no Apple TV app, and core
   `samsungtv` exposes only `['TV','HDMI']` as sources with `play_media` supporting
   `channel` only, so the TV's Apple TV app can't be launched either. Falls through
   to a notification. HACS `ollo69/ha-samsungtv-smart` would fix it.
3. **HDMI-CEC does not work on this link.** Anynet+ is enabled and the Shield
   reports `mHdmiControlEnabled: true`, `mCecOneTouchPlayEnabled: true` with a
   valid address (`0x2000`, HDMI 2), yet the TV never appears on the Shield's CEC
   bus (`dumpsys hdmi_control` lists only the Shield). Suspected HDMI cable without
   the CEC line. Not blocking — Wake-on-LAN covers TV power — but fixing it would
   add automatic input switching.
