import 'dart:convert';
import 'dart:io'; // Import for Platform
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

// --- MULTI-ROOM STORAGE ---
// Instead of one list, we use a Map: RoomID -> Tournament Data
Map<String, Map<String, dynamic>> rooms = {};

// Helper to get or create a room instance
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

  // 1. UPDATE PASSWORD
  router.post('/<room>/update-password', (Request request, String room) async {
    final data = jsonDecode(await request.readAsString());
    var r = getRoom(room);
    r['pass'] = data['newPassword'];
    return Response.ok(jsonEncode({'status': 'success'}));
  });

  // 2. VERIFY ADMIN
  router.post('/<room>/verify-admin', (Request request, String room) async {
    final data = jsonDecode(await request.readAsString());
    var r = getRoom(room);
    if (data['password'] == r['pass']) return Response.ok(jsonEncode({'auth': true}));
    return Response(401, body: jsonEncode({'auth': false}));
  });

  // 3. JOIN
  router.post('/<room>/join', (Request request, String room) async {
    final data = jsonDecode(await request.readAsString());
    var r = getRoom(room);
    List pList = r['players'];
    if (!pList.any((p) => p['name'] == data['name'])) {
      pList.add({'name': data['name'], 'points': 0.0, 'sos': 0.0});
    }
    return Response.ok(jsonEncode({'status': 'success'}));
  });

  // 4. GET STATUS (Updated logic)
  router.get('/<room>/status', (Request request, String room) {
    var r = getRoom(room);
    if (r['isFinished']) return Response.ok(jsonEncode({'status': 'finished'}));
    if (r['assignments'].isNotEmpty) {
      return Response.ok(jsonEncode({
        'status': 'started', 
        'assignments': r['assignments'],
        'round': r['round'],
        'maxRounds': r['maxRounds']
      }));
    }
    return Response.ok(jsonEncode({'status': 'waiting'}));
  });

  // 5. GET PLAYERS (With SoS Logic preserved)
  router.get('/<room>/players', (Request request, String room) {
    var r = getRoom(room);
    List players = r['players'];
    List history = r['history'];

    for (var player in players) {
      double sosScore = 0.0;
      var myMatches = history.where((entry) => entry['player'] == player['name']).toList();
      for (var match in myMatches) {
        var opponents = history.where((e) => e['round'] == match['round'] && e['table'] == match['table'] && e['player'] != player['name']);
        for (var opp in opponents) {
          var oppData = players.firstWhere((p) => p['name'] == opp['player'], orElse: () => {'points': 0.0});
          sosScore += (oppData['points'] as num).toDouble();
        }
      }
      player['sos'] = sosScore;
    }
    players.sort((a, b) => (b['points'] as num).compareTo(a['points'] as num) != 0 
      ? (b['points'] as num).compareTo(a['points'] as num) 
      : (b['sos'] as num).compareTo(a['sos'] as num));

    return Response.ok(jsonEncode(players));
  });
  // 5. REPORT RESULT
  router.post('/<room>/report-result', (Request request, String room) async {
    final data = jsonDecode(await request.readAsString());
    var r = getRoom(room);
    if (data['adminKey'] != r['pass']) return Response(403);

    String playerName = data['name'];
    double pts = (data['points'] as num).toDouble();

    for (var p in r['players']) {
      if (p['name'] == playerName) {
        p['points'] = (p['points'] as num).toDouble() + pts;
        r['history'].insert(0, {
          'player': playerName,
          'rank': data['rank'], 
          'points': pts,
          'round': r['round'],
          'table': data['table'],
          'time': DateTime.now().toString().substring(11, 16)
        });
      }
    }
    return Response.ok(jsonEncode({'status': 'success'}));
  });

  // 6. START NEXT ROUND
  router.post('/<room>/start', (Request request, String room) async {
    var r = getRoom(room);
    List players = r['players'];
    if (players.isEmpty) return Response.badRequest(body: 'No players!');

    final body = await request.readAsString();
    if (body.isNotEmpty) {
      final data = jsonDecode(body);
      if (data['adminPassword'] != r['pass']) return Response(403);
      r['maxRounds'] = data['maxRounds'] ?? r['maxRounds'];
    }

    if (r['round'] == 0) players.shuffle();
    
    if (r['round'] >= r['maxRounds']) {
      r['isFinished'] = true;
      r['assignments'] = []; 
      return Response.ok(jsonEncode({'status': 'finished'}));
    }

    r['round']++;
    players.sort((a, b) => (b['points'] as num).compareTo(a['points'] as num) != 0 
      ? (b['points'] as num).compareTo(a['points'] as num) 
      : (b['sos'] as num).compareTo(a['sos'] as num));

    List assignments = [];
    int total = players.length;
    
    if (total == 6) {
      for(int i=0; i<2; i++) {
        assignments.add({
          'table': i + 1,
          'players': players.sublist(i*3, (i*3)+3).map((p) => p['name'] as String).toList(),
        });
      }
    } else {
      int pPerTable = 4;
      for (var i = 0; i < total; i += pPerTable) {
        int end = (i + pPerTable < total) ? i + pPerTable : total;
        assignments.add({
          'table': (i ~/ pPerTable) + 1,
          'players': players.sublist(i, end).map((p) => p['name'] as String).toList(),
        });
      }
    }
    r['assignments'] = assignments;
    return Response.ok(jsonEncode({'status': 'started', 'round': r['round'], 'assignments': assignments}));
  });

  // 7. UNDO LAST ACTION
  router.post('/<room>/undo', (Request request, String room) async {
    final data = jsonDecode(await request.readAsString());
    var r = getRoom(room);
    if (data['adminPassword'] != r['pass']) return Response(403);

    if (r['history'].isNotEmpty) {
      var lastLog = r['history'].removeAt(0);
      for (var p in r['players']) {
        if (p['name'] == lastLog['player']) {
          p['points'] = (p['points'] as num) - (lastLog['points'] as num);
        }
      }
      return Response.ok(jsonEncode({'status': 'undone'}));
    }
    return Response.badRequest(body: 'History empty');
  });

  // 8. RESET ROOM
  router.get('/<room>/reset', (Request request, String room) {
    rooms[room] = {
      'players': [],
      'assignments': [],
      'history': [],
      'round': 0,
      'maxRounds': 3,
      'isFinished': false,
      'pass': 'admin123',
    };
    return Response.ok(jsonEncode({'status': 'reset'}));
  });

  // 9. STATUS & HISTORY & EXPORT
  router.get('/<room>/status', (Request request, String room) {
    var r = getRoom(room);
    if (r['isFinished']) return Response.ok(jsonEncode({'status': 'finished'}));
    return Response.ok(jsonEncode({
      'status': r['assignments'].isEmpty ? 'waiting' : 'started', 
      'assignments': r['assignments'],
      'round': r['round'],
      'maxRounds': r['maxRounds']
    }));
  });

router.get('/<room>/history', (Request request, String room) => 
    Response.ok(jsonEncode(getRoom(room)['history'])));

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final handler = Pipeline().addMiddleware(logRequests()).addMiddleware(_addCorsHeaders).addHandler(router.call);
  await io.serve(handler, '0.0.0.0', port);
  print('BEDH Cloud Server running on port $port');
}