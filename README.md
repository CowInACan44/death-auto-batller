# Graveyard Autobattler

A 2D graveyard/cemetery-themed autobattler built in Godot 4.

## Project structure

```
scenes/
  main_menu/  Main menu (Start -> fresh run)
  battle/     Battle scene (4v4 grave slots, plays one Night per load)
  shop/       Gravedigger shop scene
  game_over/  Game Over screen (Retry)
  game_won/   Game Won screen (Retry)
  unit/       Base creature/unit scene
scripts/
  main_menu/  Main menu script
  battle/     Battle scene script, CombatResolver, EncounterGenerator
  shop/       Shop scene script
  game_over/  Game Over screen script
  game_won/   Game Won screen script
  unit/       Unit scene script
  resources/  Resource scripts (CreatureData, Ability, OwnedCreature)
resources/
  creatures/  CreatureData .tres instances (5 evolution lines x 3 stages, 5 bonus)
  abilities/  Ability .tres instances
autoload/     Singletons: CreaturePool, Economy, RoundManager
```

## Current state

Backend game loop is implemented end-to-end, console-testable (no UI yet):
shop (weighted, shiny-aware) -> buy -> merge/evolve -> grave slots -> tick-based
auto-battle with ability triggers -> bones payout -> next round. A 7-night run
with a boosted Night 7 boss encounter, 3-heart loss tracking, and Game
Over/Game Won screens with Retry are wired up via real scene transitions.
Still no visual/UI polish — everything is confirmed via console prints.
