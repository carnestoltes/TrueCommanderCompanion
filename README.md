# Commander BEDH Tournament Manager
### *Advanced Swiss Pairing & Result Management for Multiplayer Pods*

[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Scryfall API](https://img.shields.io/badge/API-Scryfall-red?style=for-the-badge)](https://scryfall.com/docs/api)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg?style=for-the-badge)](https://www.gnu.org/licenses/gpl-3.0)

**Commander BEDH** is a full-stack tournament management system specifically engineered for the unique challenges of 4-player Commander (EDH) pods. It replaces naive pairing systems with a **Balanced Swiss** model to ensure competitive integrity.

---

## System Architecture

**Backend:** A Dart server using the shelf package. It manages the global state (players, history, tables) in memory.

**Frontend:** A Flutter application with two distinct roles: Admin (controls the tournament flow) and Player (views assignments and rankings).

```bash
TrueCommanderCompanion/
├── apps/
│   ├── server/           # Shelf-based Dart REST API
│   └── true_commander/   # Flutter Mobile App (Android/iOS)
└── packages/
    └── shared_logic/     # Shared Domain Models & Swiss Services
```

## Server Module

* [Server Schedule](apps/server/bin/README.md)

## APP Module

* [App Schedule](apps/true_command/lib/README.md)

# Key Features

**1. Adaptative Pairing Engine**

*Dynamic Scaling:* Automatically generates optimal 4-player pods, scaling to 3-player pods only when mathematically necessary.

*1v1 Support:* Fully supports a "Dual" modality with standard 1v1 Swiss pairings.

*Balanced Swiss Model:* Unlike "Naive Swiss," our algorithm seeds pods to ensure a fair distribution of player strength, preventing "Death Tables" where top players eliminate each other early.

**2. Real Strength of Schedule (SoS)**

Unlike simple tie-breakers, this system uses the Buchholz System:

*Calculation:* A player's SoS is the sum of the current total points of every opponent they have faced.

*Why it works:* It rewards players who played against tougher opponents. If your Round 1 opponent goes on to win the whole tournament, your SoS increases automatically.

**3. Comprehensive Deck Validation**

*Scryfall Integration:* Real-time decklist validation checking for card legality and budget limits.

*Buffer Logic:* Automatically applies a 10% price buffer to account for market fluctuations.

*UX-Focused:* Features a smooth progress-driven UI to handle large batch queries without user anxiety.

**4. Admin "In-Game" Rules**

To handle the "Draw" problem in timed Commander rounds, the Admin can trigger a randomized tie-breaker rule (16.6% probability) based on:

### Motivation

The point is reaching the way to break the tie in a way fairness and not suggested for early abuse playing around it.

* The rule only assign when the admin in one of the round select the option.

For improve the experience in game and trying to minimize the role playing around this rules, i will extend and implement a 6 specific rules obtaining as result a probability of 16,6% equally. The presentation of tiebreaker rules are show below:

### Total Life

Means a total life a player has in the moment ends the time of the round (actually).

### Priority Order

In this case, the rule applies the tie break using the clockwise, so the player has start will be the first eliminated and go on in order.

### Commander Damage Inflicted

Total damage inflicted from your commander to others players.

### Commander Damage Received

Against the previous rule, total damage received from others commander players to you.

### Number of Permanents (excluding tokens and lands)

This rules applies the logical of count a buch of permanents in your board *excluding lands and tokens.*

### Number of Mana Sources (permanents)

Account for number of entites could produce mana like, mana rocks, mana dorks ...

## External Resources

[Budget Elder Dragon Highlander](https://sites.google.com/view/magicbedh)

[Reglamento](rules/reglasBEDH.pdf)

[Ruling](rules/rulesBEDH.pdf)

## ❤️ Acknowledgments

Dedicated to my brother, the visionary behind the BEDH modality. His commitment to prioritizing player ingenuity over "expensive staples" remains the core philosophy of this project.



