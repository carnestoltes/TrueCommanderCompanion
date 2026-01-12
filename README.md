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

## Features

#Swiss Algorithm

