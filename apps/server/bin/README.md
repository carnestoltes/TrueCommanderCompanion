# Description

## Key Endpoints

|Endpoint|Method|Description|
|--------|------|-----------|
|/join|POST|Adds a new player to the lobby.|
|/players|GET|Returns sorted rankings (Points > SoS). Triggers SoS calculation.|
|/status|GET|"Returns current round, table assignments, and tournament state."|
|/report-result|POST|Records a rank (1º-4º) for a player. Updates points and history.|
|/start|POST|Pairs players into pods and increments the round counter.|
|/undo|POST|Removes a specific history entry and reverts points.|

## Dependencies
* 'dart:convert';
* 'package:shelf/shelf.dart';
* 'package:shelf/shelf_io.dart' as io;
* 'package:shelf_router/shelf_router.dart';
* //import 'package:dotenv/dotenv.dart'; *(In case you want use an environment variable for manage the password)*
