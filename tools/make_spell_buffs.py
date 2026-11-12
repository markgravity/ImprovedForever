#!/usr/bin/env python3
"""ImprovedForever_Immersion/SpellBuffs.lua: what a spell leaves on you, from Forever's own client
tables (SpellEffect + SpellName, build of the Forever client). The Spell tracker watches that, not the spell:
- a totem spell (Effect 28 summon, name ends "Totem") -> the aura spell of the same name without
  " Totem" that has an area-aura effect (65): Strength of Earth Totem -> Strength of Earth
- a weapon enchant spell (Effect 360 / 54): Rockbiter Weapon, Flametongue Weapon... -> "weapon"
Keyed by spell name (a rank is the spell)."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import make_library_data as m

names = {int(r["ID"]): r["Name_lang"] for r in m.wago_table("SpellName")}
eff = m.wago_table("SpellEffect")
area = {names[int(r["SpellID"])] for r in eff if r["Effect"] in ("27", "35", "65", "119", "128") and int(r["SpellID"]) in names}
totems, weapons = {}, set()
for r in eff:
    name = names.get(int(r["SpellID"]))
    if not name:
        continue
    if r["Effect"] == "28" and name.endswith(" Totem"):
        buff = name[:-len(" Totem")]
        if buff in area:
            totems[name] = buff
    elif r["Effect"] in ("360", "54") and name.endswith(" Weapon") and not name.startswith("Engrave"):
        weapons.add(name)

out = ["-- Made by tools/make_spell_buffs.py from Forever's client tables (SpellEffect, SpellName). Do not edit.",
       "local IF = ImprovedForever", "IF.SpellBuffs = {"]
for name in sorted(totems):
    out.append(f'    [{name!r}] = {{ aura = {totems[name]!r} }},'.replace("'", '"'))
for name in sorted(weapons):
    out.append(f'    [{name!r}] = {{ weapon = true }},'.replace("'", '"'))
out.append("}")
open(os.path.join(os.path.dirname(__file__), "..", "ImprovedForever_Immersion", "SpellBuffs.lua"), "w").write("\n".join(out) + "\n")
print(len(totems), "totems,", len(weapons), "weapon enchants")
