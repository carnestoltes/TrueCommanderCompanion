import '../domain/player.dart';
import '../domain/table.dart';

class SwissPairingService {
  List<GameTable> generateBalancedSwiss(List<Player> players) {
    // 1. Sort players by match points (Descending)
    // O(n log n)
    List<Player> sortedPlayers = List.from(players);
    sortedPlayers.sort((a, b) => b.matchPoints.compareTo(a.matchPoints));

    // 2. Determine number of tables (Aiming for 4 players per table)
    int totalPlayers = sortedPlayers.length;
    int numTables = (totalPlayers / 4).ceil();
    
    // Initialize empty tables
    List<List<Player>> tableGroups = List.generate(numTables, (_) => []);

    // 3. Snake Distribution logic
    // O(n) - Total complexity stays well within O(n^2)
    bool movingForward = true;
    int currentTable = 0;

    for (var player in sortedPlayers) {
      tableGroups[currentTable].add(player);

      if (movingForward) {
        if (currentTable < numTables - 1) {
          currentTable++;
        } else {
          movingForward = false; // Hit the end, turn back
        }
      } else {
        if (currentTable > 0) {
          currentTable--;
        } else {
          movingForward = true; // Hit the start, turn forward
        }
      }
    }

    // 4. Wrap into GameTable objects
    return List.generate(tableGroups.length, (i) {
      return GameTable(
        tableNumber: i + 1,
        players: tableGroups[i],
      );
    });
  }
}