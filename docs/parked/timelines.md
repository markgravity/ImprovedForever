# Parked: buff and cooldown timelines (Interface module)

Parked 2026-10-18. The code is `docs/parked/BuffTimeline.lua` (last working version, not
loaded). Out of combat it works; in combat Forever hides what it needs, so it was taken out
until the client allows it.

## What it did
Two timelines along the bottom of the screen, on the experience line:
- **Buffs** (left: after the minion card, up to the party cards): your buffs and debuffs, each
  placed by the time it has left on a log scale (far end: 30 min or more, or no end), sliding
  toward the middle as it runs out. In place of the game's BuffFrame / DebuffFrame (faded with
  `IF.Focus.Fade`, mouse covered with `UF.Cover`; Edit Mode shows the game's).
- **Cooldowns** (right: after the party cards / party pad, up to the spell diamonds): the
  cooldowns of every slot of the gamepad bar's page (page unit slots 1-32, deduped) and the
  on-use trinkets (13, 14), while they cool, coloured red to green (`IN.LEVEL_COLORS`), flashing
  green 1 s as they come ready. In place of the Cooldown Manager (Essential / Utility viewers).
- Each icon: round (`gamepad-actionbar-circleslot-*`), half the Cooldown Manager's icon size, a
  stem down to a card-style dot on the experience line (buff / debuff type / clock icon), its
  effect in short over it (AuraLabels' `Effect`), time left under it (over it for cooldowns).
  Icons slide in from above and leave upward; crowded icons are pushed apart, then a row up.
  The middle stays clear for the party cards (`(4 * CARD_W + 3 * GAP) / 2` + 28). A short
  black notch in the experience line marks each lane's near end.
- Settings: `buffTimeline`, `cooldownTimeline` (Interface editor, groups frames / pad).

## Why it's parked (Forever 1.60.x, measured)
- **Auras in combat:** every aura read from addon code throws ("Auras cannot be accessed when
  secret while tainted"): `C_UnitAuras.GetAuraDataByIndex`, by instance ID, UNIT_AURA's update
  info (secret tables). Nothing new can be seen: debuffs landing on you, buffs others cast on
  you, a buff removed early.
- **Cooldowns in combat:** `C_ActionBar.GetActionCooldown`'s startTime / duration are secret
  (isActive / isOnGCD are not). Duration objects (`GetActionCooldownDuration`,
  `C_UnitAuras.GetAuraDuration`) give back only secret values, also through our own curve
  (`EvaluateRemainingDuration`): checked with a probe.
- **No geometry from secrets:** a secret can drive a bar's fill (`StatusBar:SetValue`), a
  cooldown swipe (`SetCooldownFromDurationObject`), text (`C_DurationUtil.CreateDurationTextBinding`),
  alpha and colour, but no size or position. `StatusBar:SetTimerDuration` takes a secret only
  from Blizzard code. A Blizzard forum thread on exactly this ("space = time" timelines):
  "You won't be able to effect geometry with secrets."
- Your own casts stay readable (`UNIT_SPELLCAST_SUCCEEDED`, spell ID).

## Workarounds tried or considered (all partial)
- **Timers of our own** (in the parked code; as ForeverCDM, Cooldown Master, CooldownCue do):
  ends read out of combat keep ticking; a cast starts a cooldown's timer with its length learnt
  out of combat (read whole, else the tooltip's "8 sec cooldown" / "(2 Min Cooldown)", else
  `GetSpellBaseCooldown`), saved per character (`charDB.timelineLengths`); a buff you cast on
  yourself refreshed / added from its learnt length. Gaps: everything listed above as unseeable,
  and a buff cast on someone else taken for yours. Judged too limited.
- **Icon on a bar's fill:** an invisible StatusBar per icon, `SetValue(duration:EvaluateRemainingDuration(logCurve))`
  each frame, the icon anchored to the fill texture's end, so the engine moves it. Untested
  (`/if tlbar`, removed). Even working, it can't push icons apart (positions unreadable) and
  needs a duration object, which auras don't give in combat.

## To re-add
Watch for: auras readable in combat (or a whitelist for your own buffs:
`C_Secrets.ShouldSpellAuraBeSecret(id)` false), cooldown times readable
(`C_Secrets.ShouldSpellCooldownBeSecret(id)` / `ShouldActionCooldownBeSecret` false), or an API
setting a region's offset / width from a duration object. `/if tlprobe` (in the parked file)
logs what can be read in a fight into `ImprovedForeverDB.timelineProbe`.

Then:
1. Move `BuffTimeline.lua` back into `ImprovedForever_Interface/`, after `AuraLabels.lua` in the
   `.toc`.
2. Restore what it used, removed with it:
   - `PartyCards.lua`: `PC.ROW_HALF = (4 * CARD_W + 3 * GAP) / 2`.
   - `HudLayout.lua`: `HL.CooldownIconSize()` (returns `IconSize(_G.EssentialCooldownViewer)`).
   - `AuraLabels.lua`: `AL.Effect = Effect`, and skip its labels while `buffTimeline` is on.
3. `Module.lua`: the defaults `buffTimeline = true`, `cooldownTimeline = true`; the `tlprobe`
   command; drop their clean-up from `IN.Settings()`.
4. `InterfaceEditor.lua`: the two toggles (`Toggle(key, label, function() IN.BuffTimeline.Apply() end)`).
5. Drop the combat workarounds the client no longer needs, and remove the probe once it works.

Sources: [ForeverCDM](https://github.com/Thunderz96/forever-addon-kit) (Forever measurements),
[Warcraft Wiki: Secret Values](https://warcraft.wiki.gg/wiki/Secret_Values),
[Blizzard forum: "Space = Time" with secret values](https://us.forums.blizzard.com/en/wow/t/120-question-visualizing-space-time-with-secret-values/2225774),
[CooldownCue](https://github.com/demsix/CooldownCue), [Cooldown Master](https://www.curseforge.com/wow/addons/cooldown-master).
