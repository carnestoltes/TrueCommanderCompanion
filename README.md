# TrueCommanderCompanion
Fair assignment of manage for tournament in multipalyer commander

## High Level Architecture

```bash
lib/
│
├── main.dart
│
├── domain/
│   ├── player.dart
│   ├── table.dart
│   ├── match.dart
│   ├── round.dart
│   ├── tournament.dart
│   └── rule.dart
│
├── services/
│   ├── swiss_pairing_service.dart
│   ├── scoring_service.dart
│   ├── rule_assignment_service.dart
│   └── timer_service.dart
│
├── data/
│   ├── repositories/
│   │   ├── player_repository.dart
│   │   └── tournament_repository.dart
│   │
│   └── local_db.dart
│
├── ui/
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── tournament_screen.dart
│   │   ├── round_screen.dart
│   │   └── standings_screen.dart
│   │
│   └── widgets/
│       ├── player_tile.dart
│       ├── table_card.dart
│       └── timer_widget.dart
│
└── utils/
    ├── constants.dart
    └── helpers.dart
```

# Features

## Swiss Algorithm

### Design Rules
* Prefer tables of 4 players
* Allow tables of 3 players only when unavoidable

Example scenario

An 8 players end the first round and the score result is:

|Player|Points|
|------|------|
|   A  |  12  |
|   B  |  11  |
|   C  |  10  |
|   D  |  9   |
|   E  |  6   |
|   F  |  5   |
|   G  |  4   |
|   H  |  3   |

Model of **naive swiss** take the four player with the most score in one table and the tail of other four in the other table so, making the avg of two pairing, the first table has an avg of 10.5 points against the second tables has only an avg of 4.5.
Translation meaning, death teable vs free win table, strong player elimated each other while weak players farm points.

Our model, **balanced swiss**, transition and put in table one A,D,E,H and table two B,C,F,G given as result of avg in point 7.5 in each table.

Result, in each match obtain 1 strong player, 1 mid-strong player, 1 mid-weak player and 1 weak player.

* Minimize the number of repeated opponents thought the tournament rounds

Example scenario

Exist eight players in the event, A .. H and player A already plays with B, C and D so E,F,G,H are preferred but just in case we need it, player A repeat pairing against player B,C or D dependending of global classification.

* Balance average points

Using snake distribution approach, sorting player for swiss, adapting tables for preferred maximum tables of 4 players and applies a round robin across tables algorithm.

Example scenario

In each round take each player for the beggining or the end of tail, i mean:
Round 1 --> P1 in T1, P2 in T2, P3 in T3.
Round 2 (asuming the scale of points) --> P4 in T3, P5 in T2 and P6 in T1.
The order of assignment the tables use reverse order but still respecfully with swiss normative.

**Complexity in the worst case: O(n^2)**

## Rule Assignment
### Motivation
The point is reaching the way to break the tie in a way fairness and not suggested for early abuse playing around it.

* Rule are not visible at the beggining of each round
* The rule only assign when the timer ends or the user click on "See rule"

