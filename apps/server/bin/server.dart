import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

// ---------------- MULTI-ROOM STORAGE ----------------
Map<String, Map<String, dynamic>> rooms = {};

const String backupPath = 'tournament_backup.json';

Map<String, dynamic> getRoom(String id) {
  return rooms.putIfAbsent(id, () => {
        'players': [],
        'assignments': [],
        'history': [],
        'round': 0,
        'maxRounds': 3,
        'isFinished': false,
        'pass': 'admin123',
      });
}

// SAVE: Call this every time a score is reported or a round starts
void saveStateToFile(Map roomData) {
  try {
    final file = File(backupPath);
    file.writeAsStringSync(jsonEncode(roomData));
    print("Backup saved successfully.");
  } catch (e) {
    print("Error saving backup: $e");
  }
}

// LOAD: Call this when the server first starts up
Map<String, dynamic>? loadStateFromFile() {
  try {
    final file = File(backupPath);
    if (file.existsSync()) {
      final String content = file.readAsStringSync();
      if (content.isEmpty) return null;
      
      // Decode as dynamic first, then cast
      final dynamic decoded = jsonDecode(content);
      return Map<String, dynamic>.from(decoded);
    }
  } catch (e) {
    print("No backup found or error loading: $e");
  }
  return null;
}

// DELETE: Call this inside your "Finish Tournament" route
void deleteBackup() {
  final file = File(backupPath);
  if (file.existsSync()) {
    file.deleteSync();
    print("Tournament finished: Backup deleted.");
  }
}

// ---------------- CORS ----------------
Handler _addCorsHeaders(Handler handler) {
  return (Request request) async {
    if (request.method == 'OPTIONS') {
      return Response.ok('', headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type',
      });
    }
    final response = await handler(request);
    return response.change(headers: {
      ...response.headers,
      'Access-Control-Allow-Origin': '*',
    });
  };
}

void main() async {
  final router = Router();

 var savedData = loadStateFromFile();
  if (savedData != null) {
    // Cast the generic Map to the specific types the compiler wants
    Map<String, dynamic> recoveredRoom = Map<String, dynamic>.from(savedData);
    
    String roomId = recoveredRoom['id']?.toString() ?? 'default'; 
    rooms[roomId] = recoveredRoom;
    
    print("Resilience Active: Recovered tournament $roomId");
  }

  // ================= API ROUTES =================
  // Everything now under /api

  router.post('/api/<room>/update-password',
      (Request request, String room) async {
    final data = jsonDecode(await request.readAsString());
    var r = getRoom(room);
    r['pass'] = data['newPassword'];
    return Response.ok(jsonEncode({'status': 'success'}));
  });

  router.post('/api/<room>/verify-admin',
      (Request request, String room) async {
    final data = jsonDecode(await request.readAsString());
    var r = getRoom(room);
    if (data['password'] == r['pass']) {
      return Response.ok(jsonEncode({'auth': true}));
    }
    return Response(401, body: jsonEncode({'auth': false}));
  });

  router.post('/api/<room>/join', (Request request, String room) async {
  var r = getRoom(room);
  var data = jsonDecode(await request.readAsString());
  String name = data['name'];

  if (r['players'].length >= 64) {
    return Response.badRequest(body: 'Tournament is full (64 max)!');
  }

  // Check if player already exists but was "dropped"
  var existing = r['players'].firstWhere((p) => p['name'] == name, orElse: () => null);
  if (existing != null) {
    existing['isDropped'] = false; // "Un-drop" them if they rejoin
  } else {
    r['players'].add({
      'name': name,
      'points': 0.0,
      'sos': 0.0,
      'isDropped': false,
    });
  }
  return Response.ok('Joined');
});

  router.get('/api/<room>/players', (Request request, String room) {
    var r = getRoom(room);
    List players = r['players'];
    List history = r['history'];

    for (var player in players) {
      double sosScore = 0.0;
      var myMatches =
          history.where((entry) => entry['player'] == player['name']);
      for (var match in myMatches) {
        var opponents = history.where((e) =>
            e['round'] == match['round'] &&
            e['table'] == match['table'] &&
            e['player'] != player['name']);
        for (var opp in opponents) {
          var oppData = players.firstWhere(
              (p) => p['name'] == opp['player'],
              orElse: () => {'points': 0.0});
          sosScore += (oppData['points'] as num).toDouble();
        }
      }
      player['sos'] = sosScore;
    }

    players.sort((a, b) =>
        (b['points'] as num).compareTo(a['points'] as num) != 0
            ? (b['points'] as num).compareTo(a['points'] as num)
            : (b['sos'] as num).compareTo(a['sos'] as num));

    return Response.ok(jsonEncode(players));
  });

 router.post('/api/<room>/restore', (Request request, String room) async {
  final body = await request.readAsString();
  final dynamic decodedData = jsonDecode(body);
  
  // Convert 'dynamic' to 'Map<String, dynamic>'
  final Map<String, dynamic> data = Map<String, dynamic>.from(decodedData);
  
  rooms[room] = data; // Now the compiler is happy
  saveStateToFile(data); 
  
  return Response.ok('Tournament Restored');
});


  router.post('/api/<room>/remove-player', (Request request, String room) async {
    var r = getRoom(room);
    var data = jsonDecode(await request.readAsString());
    String name = data['name'];

    var p = r['players'].firstWhere((p) => p['name'] == name, orElse: () => null);
    if (p != null) {
      p['isDropped'] = true; // Mark as dropped instead of deleting
      return Response.ok('Player dropped');
    }
    return Response.badRequest(body: 'Player not found');
  });
  router.get('/api/<room>/history',
      (Request request, String room) =>
          Response.ok(jsonEncode(getRoom(room)['history'])));
          
  router.get('/api/<room>/status', (Request request, String room) {
  var r = getRoom(room);
  return Response.ok(jsonEncode({
    'status': r['isFinished'] ? 'finished' : (r['assignments'].isEmpty ? 'waiting' : 'started'),
    'round': r['round'],
    'assignments': r['assignments'],
  }));
});


router.get('/api/<room>/reset', (Request request, String room) {
  if (rooms.containsKey(room)) {
    rooms[room] = {
      'players': [],
      'assignments': [],
      'history': [],
      'round': 0,
      'maxRounds': 3,
      'isFinished': false,
      'pass': rooms[room]!['pass'], // Keep the same password
    };
    return Response.ok(jsonEncode({'status': 'reset successful'}));
  }
  return Response.notFound('Room not found');
});

router.get('/api/<room>/export', (Request request, String room) {
  var r = getRoom(room);
  List players = r['players'];
  List history = r['history'];

  StringBuffer report = StringBuffer();
  report.writeln("--- TOURNAMENT REPORT: $room ---");
  report.writeln("FINAL STANDINGS:");
  
  for (var p in players) {
    report.writeln("${p['name']}: ${p['points']} pts (SoS: ${p['sos']})");
  }

  report.writeln("\nMATCH HISTORY:");
  for (var entry in history) {
    report.writeln("Round ${entry['round']} | Table ${entry['table']} | ${entry['player']} - Rank: ${entry['rank']}");
  }

  return Response.ok(report.toString());
});

router.post('/api/<room>/undo', (Request request, String room) async {
  final data = jsonDecode(await request.readAsString());
  var r = getRoom(room);
  
  // 1. Remove from history
  r['history'].removeWhere((entry) => 
    entry['player'] == data['playerName'] && 
    entry['round'] == data['round']
  );

  // 2. Subtract points from the player
  var player = r['players'].firstWhere((p) => p['name'] == data['playerName']);
  player['points'] = (player['points'] as num) - (data['pointsToRemove'] as num);

  return Response.ok(jsonEncode({'status': 'undone'}));
});

router.post('/api/<room>/report-result', (Request request, String room) async {
  final data = jsonDecode(await request.readAsString());
  var r = getRoom(room);
  
  // Update the player's total points
  var player = r['players'].firstWhere((p) => p['name'] == data['name']);
  player['points'] = (player['points'] as num) + (data['points'] as num);
  
  // Add to history log
  r['history'].add({
    'player': data['name'],
    'points': data['points'],
    'rank': data['rank'],
    'table': data['table'],
    'round': r['round'],
  });
  
  // NEW: Save to JSON for resilience
  saveStateToFile(r);
  return Response.ok(jsonEncode({'status': 'success'}));
});

  // ---------------- START ROUND ----------------
router.post('/api/<room>/start', (Request request, String room) async {
  var r = getRoom(room);
  List players = r['players'];
  List history = r['history'];
  List assignments = r['assignments'];
  int currentRound = r['round'] ?? 0;

  // 1. Basic Validation
  if (players.isEmpty) {
    return Response.badRequest(body: jsonEncode({'error': 'No players in the room!'}));
  }

  // 2. Safety Check: Ensure everyone from the PREVIOUS round reported
  if (currentRound > 0 && assignments.isNotEmpty) {
    List<String> assignedNames = [];
    for (var table in assignments) {
      assignedNames.addAll(List<String>.from(table['players']));
    }

    for (var pName in assignedNames) {
      bool hasReported = history.any((entry) => 
        entry['player'] == pName && entry['round'] == currentRound
      );

      if (!hasReported) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Waiting for result from: $pName'}),
          headers: {'content-type': 'application/json'}
        );
      }
    }
  }

  // 3. Prepare for New Round
  r['round'] = currentRound + 1;
  r['status'] = 'started';

  // 4. Filter Active Players (Exclude Dropped)
  // We take a shallow copy to avoid mutating the main list during sorting
  List activePlayers = players.where((p) => p['isDropped'] != true).toList();

  // 5. Swiss Sorting Logic
  // Sort by Points (Primary) then SoS (Secondary)
  activePlayers.sort((a, b) {
    int cmp = (b['points'] as num).compareTo(a['points'] as num);
    if (cmp == 0) {
      num sosA = a['sos'] ?? 0;
      num sosB = b['sos'] ?? 0;
      return sosB.compareTo(sosA);
    }
    return cmp;
  });

  // 6. Create Tables (Swiss Pairing)
  List newAssignments = [];
  int tableCounter = 1;

  // Algorithm to prioritize 4-player tables, falling back to 3-player tables
  while (activePlayers.length >= 3) {
    int size = 4;
    // Special cases to ensure no one is left alone (e.g., 6 players = two 3-player tables)
    if (activePlayers.length == 6 || activePlayers.length == 5 || activePlayers.length == 9) {
      size = 3;
    } else if (activePlayers.length < 4) {
      size = 3;
    }

    List tableNames = [];
    for (int i = 0; i < size; i++) {
      tableNames.add(activePlayers.removeAt(0)['name']);
    }

    newAssignments.add({
      'table': tableCounter++,
      'players': tableNames,
    });
  }

  // 7. Handle "The Bye" (If 1 or 2 players are left)
  if (activePlayers.isNotEmpty) {
    for (var p in activePlayers) {
      // Record the Bye in history immediately
      r['history'].add({
        'player': p['name'],
        'round': r['round'],
        'points': 4.0, // Automatic win for a Bye
        'rank': 1,
        'table': 0, // Table 0 = Bye
      });
      
      // Update the player's points in the main list
      var playerInMainList = players.firstWhere((element) => element['name'] == p['name']);
      playerInMainList['points'] = (playerInMainList['points'] as num) + 4.0;
    }
  }

  r['assignments'] = newAssignments;

  return Response.ok(
    jsonEncode({
      'status': r['status'],
      'round': r['round'],
      'assignments': r['assignments']
    }),
    headers: {'content-type': 'application/json'}
  );
});

 // ================= STATIC FLUTTER WEB =================

  // 1. Detect the correct path
  final String webPath = Directory('web_bundle').existsSync() 
      ? 'web_bundle' 
      : 'web';

  final staticHandler = createStaticHandler(
    webPath,
    defaultDocument: 'index.html',
  );

  // SPA fallback (important for /admin, /room/abc refresh)
  Handler spaFallback(Handler handler) {
    return (Request request) async {
      final response = await handler(request);
      if (response.statusCode == 404 &&
          !request.url.path.startsWith('api')) {
        // Use the same webPath variable here!
        final file = File('$webPath/index.html'); 
        if (await file.exists()) {
          return Response.ok(
            await file.readAsBytes(),
            headers: {'Content-Type': 'text/html'},
          );
        }
      }
      return response;
    };
  }

  final cascade = Cascade()
      .add(router)
      .add(staticHandler)
      .handler;

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_addCorsHeaders)
      .addHandler(spaFallback(cascade));

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  //await io.serve(handler, InternetAddress.anyIPv4, port);

  await io.serve(handler, '0.0.0.0', port);
  print('Server running on port $port');
}
