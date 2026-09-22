# Graveyard Autobattler

A 2D graveyard/cemetery-themed autobattler built in Godot 4.

## Project structure

```
scenes/
  battle/    Battle scene (4v4 grave slots)
  shop/      Gravedigger shop scene
  unit/      Base creature/unit scene
scripts/
  battle/    Battle scene script
  shop/      Shop scene script
  unit/      Unit scene script
  resources/ Resource scripts (CreatureData, etc.)
resources/
  creatures/ CreatureData .tres instances (evolution lines/stages)
autoload/    Singleton scripts (game state, economy, etc.)
```

This is base project scaffolding only — no gameplay, shop, or evolution logic yet.
