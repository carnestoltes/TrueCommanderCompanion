import 'player.dart';

class GameTable {
  final int tableNumber;
  final List<Player> players;

  GameTable({
    required this.tableNumber, 
    required this.players
  });

  // A table is "Balanced" if the sum of matchPoints is similar across all tables
  double get averagePoints {
    if (players.isEmpty) return 0;
    return players.map((p) => p.matchPoints).reduce((a, b) => a + b) / players.length;
  }
}