import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
//import 'package:dotenv/dotenv.dart';

List<Map<String, dynamic>> players = [];
List<Map<String, dynamic>> currentAssignments = [];
List<Map<String, dynamic>> gameHistory = [];
int currentRound = 0;
int maxRounds = 3; 
bool tournamentFinished = false;
String admin_pass = 'admin123';

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
    return response.change(headers: {'Access-Control-Allow-Origin': '*'});
  };
}

void main() async {
  final router = Router();
  /*var env = DotEnv()..load(); // This reads the .env file automatically
  final String admin_pass = env['ADMIN_PASS'] ?? 'default';*/

  router.post('/update-password', (Request request) async {
    final data = jsonDecode(await request.readAsString());
    
    // We update the global variable above
    admin_pass = data['newPassword']; 
    
    print("Password updated to: $admin_pass");
    return Response.ok(jsonEncode({'status': 'success'}));
  });

  router.post('/verify-admin', (Request request) async {
    final data = jsonDecode(await request.readAsString());
    
    // Stricly check against the variable 'admin_pass'
    if (data['password'] == admin_pass) {
      return Response.ok(jsonEncode({'auth': true}));
    }
    return Response(401, body: jsonEncode({'auth': false}));
    });

  router.post('/join', (Request request) async {
    final data = jsonDecode(await request.readAsString());
    if (!players.any((p) => p['name'] == data['name'])) {
      players.add({'name': data['name'], 'points': 0.0, 'sos': 0.0});
    }
    return Response.ok(jsonEncode({'status': 'success'}));
  });

  router.get('/players', (Request request) {
    players.sort((a, b) {
      num pA = a['points'] ?? 0.0;
      num pB = b['points'] ?? 0.0;
      int cmp = pB.compareTo(pA);
      if (cmp == 0) {
        num sA = a['sos'] ?? 0.0;
        num sB = b['sos'] ?? 0.0;
        return sB.compareTo(sA);
      }
      return cmp;
    });
    return Response.ok(jsonEncode(players));
  });

  router.post('/undo', (Request request) async {
    final data = jsonDecode(await request.readAsString());
    if (data['adminPassword'] != admin_pass) return Response(403);
    if (gameHistory.isNotEmpty) {
      var lastLog = gameHistory.removeAt(0);
      for (var p in players) {
        if (p['name'] == lastLog['player']) {
          p['points'] = (p['points'] as num) - (lastLog['points'] as num);
          p['sos'] = (p['sos'] as num) - (lastLog['points'] as num);
        }
      }
      return Response.ok(jsonEncode({'status': 'undone'}));
    }
    return Response.badRequest(body: 'History empty');
  });

  router.get('/status', (Request request) {
    // FIX: If tournamentFinished is true, always return finished
    if (tournamentFinished) {
      return Response.ok(jsonEncode({'status': 'finished'}));
    }
    if (currentAssignments.isNotEmpty) {
      return Response.ok(jsonEncode({
        'status': 'started', 
        'assignments': currentAssignments,
        'round': currentRound,
        'maxRounds': maxRounds
      }));
    }
    return Response.ok(jsonEncode({'status': 'waiting'}));
  });

  router.post('/verify-admin', (Request request) async {
    final data = jsonDecode(await request.readAsString());
    if (data['password'] == admin_pass) return Response.ok(jsonEncode({'auth': true}));
    return Response(401, body: jsonEncode({'auth': false}));
  });

  router.get('/history', (Request request) => Response.ok(jsonEncode(gameHistory)));

  router.get('/export', (Request request) {
    // FIX: Sorting must use num, not int cast
    players.sort((a, b) {
      num pA = a['points'] ?? 0.0;
      num pB = b['points'] ?? 0.0;
      int cmp = pB.compareTo(pA);
      if (cmp == 0) return (b['sos'] as num).compareTo(a['sos'] as num);
      return cmp;
    });

    StringBuffer report = StringBuffer();
    report.writeln("=== TOURNAMENT FINAL REPORT ===");
    report.writeln("\n--- FINAL STANDINGS ---");
    for (int i = 0; i < players.length; i++) {
      report.writeln("#${i + 1}: ${players[i]['name']} - ${players[i]['points']} Pts (SoS: ${players[i]['sos']})");
    }
    return Response.ok(report.toString(), headers: {'Content-Type': 'text/plain'});
  });

  router.post('/report-result', (Request request) async {
    final data = jsonDecode(await request.readAsString());
    if (data['adminKey'] != admin_pass) return Response(403);

    String playerName = data['name'];
    double pointsToAdd = (data['points'] as num).toDouble();

    for (var p in players) {
      if (p['name'] == playerName) {
        p['points'] = (p['points'] as num).toDouble() + pointsToAdd;
        p['sos'] = (p['sos'] ?? 0.0) + pointsToAdd; 

        gameHistory.insert(0, {
          'player': playerName,
          'rank': data['rank'], 
          'points': pointsToAdd,
          'round': currentRound,
          'table': data['table'],
          'time': DateTime.now().toString().substring(11, 16)
        });
      }
    }
    return Response.ok(jsonEncode({'status': 'success'}));
  });

  router.post('/start', (Request request) async {
    if (players.isEmpty) return Response.badRequest(body: 'No players!');
    final body = await request.readAsString();
    if (body.isNotEmpty) {
      final data = jsonDecode(body);
      if (data['adminPassword'] != admin_pass) return Response(403);
      maxRounds = data['maxRounds'] ?? maxRounds;
    }

    if (currentRound >= maxRounds) {
      tournamentFinished = true;
      currentAssignments = []; 
      return Response.ok(jsonEncode({'status': 'finished'}));
    }

    currentRound++;
    players.sort((a, b) {
      num pA = a['points'] ?? 0.0;
      num pB = b['points'] ?? 0.0;
      int cmp = pB.compareTo(pA);
      if (cmp == 0) return (b['sos'] as num).compareTo(a['sos'] as num);
      return cmp;
    });

    currentAssignments = [];
    int total = players.length;
    
    // Balanced split for 6 players
    if (total == 6) {
      for(int i=0; i<2; i++) {
        currentAssignments.add({
          'table': i + 1,
          'players': players.sublist(i*3, (i*3)+3).map((p) => p['name'] as String).toList(),
        });
      }
    } else {
      int pPerTable = 4;
      for (var i = 0; i < total; i += pPerTable) {
        int end = (i + pPerTable < total) ? i + pPerTable : total;
        currentAssignments.add({
          'table': (i ~/ pPerTable) + 1,
          'players': players.sublist(i, end).map((p) => p['name'] as String).toList(),
        });
      }
    }

    return Response.ok(jsonEncode({
      'status': 'started',
      'round': currentRound,
      'assignments': currentAssignments
    }));
  });

  router.get('/reset', (Request request) {
    players.clear();
    currentAssignments.clear();
    gameHistory.clear();
    currentRound = 0;
    tournamentFinished = false;
    return Response.ok(jsonEncode({'status': 'reset'}));
  });

  final handler = Pipeline().addMiddleware(logRequests()).addMiddleware(_addCorsHeaders).addHandler(router);
  await io.serve(handler, '0.0.0.0', 8080);
  print('TrueCommander Server running on port 8080');
}