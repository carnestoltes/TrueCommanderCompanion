# TrueCommanderCompanion
Fair assignment of manage for tournament in multipalyer commander

## High Level Architecture

/domain
  Player
  Table
  Match
  Rule
  Tournament
  Round

/services
  SwissPairingService
  ScoringService
  RuleAssignmentService
  TimerService

/data
  LocalDatabase (SQLite)
  ImportService (manual / future Companion)

## Features

#Swiss Algorithm

/ui
  LobbyScreen
  TableView
  TimerView
  StandingsGrid
