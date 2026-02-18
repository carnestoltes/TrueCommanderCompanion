# Commander BEDH Tournament Manager

A full-stack tournament management system designed for Commander (EDH) pods. It features a Dart-based backend server and a Flutter mobile application for real-time table assignments, result reporting, and advanced tie-breaker calculations.

## Server Module

* [Server Schedule](apps/server/bin/README.md)

## APP Module

* [App Schedule](apps/true_command/lib/README.md)

## System Architecture

The system follows a Client-Server model over a Local Area Network (LAN).

**Backend:** A Dart server using the shelf package. It manages the global state (players, history, tables) in memory.

**Frontend:** A Flutter application with two distinct roles: Admin (controls the tournament flow) and Player (views assignments and rankings).
    
### High Level Architecture Client/Server

```bash
TrueCommanderCompanion/
│
├──apps/
│   ├── server/
│   │   ├── bin/
│   │   │    └── server.dart 
│   │   ├── test/
│   │   │    └── server_test.dart     
│   │   ├── .dockerignore
│   │   ├── .gitignore
│   │   ├── CHANGELOG.md
│   │   ├── Dockerfile
│   │   ├── README.md
│   │   ├── analysis_options.yaml
│   │   └── pubspec.yaml  
│   │    
│   ├── true_commander/
│   │   ├── android/
│   │   ├── assets/
│   │   ├── ios/
│   │   ├── lib/
│   │   │   ├── lobby_screen.dart
│   │   │   └── main.dart
│   │   ├── linux/
│   │   ├── macos/
│   │   ├── test/
│   │   ├── web/
│   │   ├── windows/
│   │   ├── .gitignore
│   │   ├── .metadata
│   │   ├── LICENSE
│   │   ├── README.md
│   │   ├── analysis_options.yaml
│   │   └── pubspec.yaml 
│   │
├──packages/shared_logic
│   └── lib/
│   │   ├── domain/
│   │   │     ├── player.dart
│   │   │     └── table.dart
│   │   └── services/
│   │   │     └── swiss_pairing_service.dart
├──.gitignore
├──LICENSE
├── pubspec.lock
├── pubspec.yaml
└── README
```

# Features

**1. Dynamic Pod Assignment**

The server automatically generates pods based on the total number of players:

* Prioritizes 4-player pods.

* Automatically creates 3-player pods if the total count isn't divisible by 4.

**2. Real Strength of Schedule (SoS)**

Unlike simple tie-breakers, this system uses the Buchholz System:

*Calculation:* A player's SoS is the sum of the current total points of every opponent they have faced.

*Why it works:* It rewards players who played against tougher opponents. If your Round 1 opponent goes on to win the whole tournament, your SoS increases automatically.

**3. Admin Tools**

__Update Server IP:__ Change connection settings without restarting the app.

__Security:__ Admin actions are protected by a server-side password.

__Undo System:__ Mistakenly reported results can be deleted, and points are automatically recalculated.

## Deployment

### Prerequisites
* [Dart SDK](https://dart.dev/get-dart)
* [Flutter SDK](https://docs.flutter.dev/install/quick)
    
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

Our model, **balanced swiss**, transition and put in table one A, D, E, H and table two B, C, F, G given as result of avg in point 7.5 in each table.

Result in each match obtain 1 strong player, 1 mid-strong player, 1 mid-weak player and 1 weak player.

* Minimize the number of repeated opponents thought the tournament rounds

Example scenario

Exist eight players in the event, A .. H and player A already plays with B, C and D so E, F, G, H are preferred but just in case we need it, player A repeat pairing against player B, C or D dependending of global classification.

* Balance average points

Using snake distribution approach, sorting player for swiss, adapting tables for preferred maximum tables of 4 players and applies a round robin across tables algorithm.

Example scenario

In each round take each player for the beggining or the end of tail, i mean:
Round 1 --> P1 in T1, P2 in T2, P3 in T3.
Round 2 (asuming the scale of points) --> P4 in T3, P5 in T2 and P6 in T1.
The order of assignment the tables use reverse order but still respecfully with swiss normative.

**Complexity in the worst case: O(n^2)**

## SoS (Strengh of Schedule)

In tournament software SoS stands for Strength of Schedule.

It is the most common tie-breaker used to rank players who have the same number of total points.

How it works:

If you and another player both have 9 points, the computer needs a way to decide who is "#1" and who is "#2." It looks at the opponents you played against:

__High SoS:__ You played against "strong" opponents (players who won most of their other matches).

__Low SoS:__ You played against "weak" opponents (players who lost most of their other matches).

The logic is that it is harder to earn 9 points against pro players than it is to earn 9 points against beginners. Therefore, the person with the higher SoS wins the tie-breaker.

## Rule Assignment

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

## Blog
[https://sites.google.com/view/magicbedh]

## Rules in Spanish
[https://drive.google.com/file/d/1JR_MFuC7W1gXlIDCWRgXho9N8UAkhSFv/view]

## Collaboration
*In this section i want to thank a person has gone to the care to develop a modality inside of Commander for make arrive everyone the posibility of a good experience agains others formats prioritizing the ingenuity versus stapples*



