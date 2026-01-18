# SeverActions

A comprehensive action and behavior framework for **SkyrimNet**, enabling AI-controlled NPCs to perform a wide variety of actions through natural dialogue. When an NPC says something like "I'll follow you" or "Take this sword," SeverActions translates that intent into actual in-game behavior.

## Key Features

- **Follower System** - NPCs can follow the player, wait, or stop following through dialogue
- **Travel System** - Send NPCs to specific locations across Skyrim with real pathfinding
- **Combat System** - Manage attacks, surrenders, ceasefires, and combat state
- **Outfit Management** - NPCs can dress, undress, or change specific clothing pieces
- **Currency Exchange** - Give gold, collect payments, or extort money
- **Item Interactions** - Pick up items, loot containers, give/receive items, use consumables
- **Furniture Use** - Sit, sleep, or use crafting stations
- **Crafting** - NPCs can craft items at forges and workstations
- **Arousal Integration** - Optional support for OSLAroused and SexLab Aroused
- **Fertility Mode Integration** - Optional pregnancy and fertility cycle awareness
- **Hotkey Support** - Quick access to common actions via configurable hotkeys
- **MCM Configuration** - In-game settings menu for customization

## Installation Requirements

### Required Mods
- Skyrim Special Edition
- SKSE64
- SkyrimNet
- PO3 Papyrus Extender
- PapyrusUtil
- SkyUI (for MCM)
- Papyrus MessageBox (Optional for the GiveItem and Travel actions)

### Optional Mod Support
- OSLAroused or SexLab Aroused (for arousal features)
- Fertility Mode Reloaded (for pregnancy features)

## Installation

1. Download the latest release
2. Extract to your Skyrim Data folder (or install via mod manager)
3. Ensure load order places SeverActions.esp after SkyrimNet.esp

## Documentation

For detailed documentation on all systems, actions, and configuration options, see the [Documentation](docs/DOCUMENTATION.md).

## Credits

- **Severause** - Author
- **SkyrimNet Team** - For the AI framework
- **Bethesda** - For Skyrim and the Creation Kit

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
