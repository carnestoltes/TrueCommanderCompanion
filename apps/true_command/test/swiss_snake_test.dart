/*import 'package:flutter_test/flutter_test.dart';
import 'package:true_command/domain/player.dart';
import 'package:true_command/services/swiss_pairing_service.dart';

void main() {
  test('Balanced Swiss Snake Distribution Test', () {
    final service = SwissPairingService();

    // 1. Create 12 players with different points (P1 has 9 pts, P12 has 0 pts)
    List<Player> mockPlayers = List.generate(12, (i) => Player(
      id: 'id_$i',
      name: 'Player ${i + 1}',
      deckList: 'Deck $i',
      matchPoints: 12 - i, // Descending points
    ));

    // 2. Run the algorithm
    final tables = service.generateBalancedSwiss(mockPlayers);

    // 3. Verifications
    print('--- Tournament Pairing Results ---');
    for (var table in tables) {
      String names = table.players.map((p) => '${p.name}(${p.matchPoints}pts)').join(', ');
      print('Table ${table.tableNumber}: $names');
      print('Average Points: ${table.averagePoints.toStringAsFixed(2)}\n');
    }

    // Check if we have 3 tables (12 players / 4)
    expect(tables.length, 3);
    
    // Check if Table 1 got Player 1 (highest) and Player 6 (snake mid)
    // Table 1 should have: P1 (12), P6 (7), P7 (6), P12 (1)
    expect(tables[0].players.any((p) => p.name == 'Player 1'), true);
    expect(tables[0].players.any((p) => p.name == 'Player 6'), true);
  });
}*/