import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

// ---------------- MULTI-ROOM STORAGE ----------------
Map<String, Map<String, dynamic>> rooms = {};

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
    final data = jsonDecode(await request.readAsString());
    var r = getRoom(room);
    List pList = r['players'];
    if (!pList.any((p) => p['name'] == data['name'])) {
      pList.add({'name': data['name'], 'points': 0.0, 'sos': 0.0});
    }
    return Response.ok(jsonEncode({'status': 'success'}));
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
  
  return Response.ok(jsonEncode({'status': 'success'}));
});

  // ---------------- START ROUND ----------------
  router.post('/api/<room>/start', (Request request, String room) async {
    var r = getRoom(room);
    List players = r['players'];

    if (players.isEmpty) {
      return Response.badRequest(body: 'No players!');
    }

    if (r['round'] == 0) players.shuffle();

    if (r['round'] >= r['maxRounds']) {
      r['isFinished'] = true;
      r['assignments'] = [];
      return Response.ok(jsonEncode({'status': 'finished'}));
    }

    r['round']++;
    players.sort((a, b) =>
        (b['points'] as num).compareTo(a['points'] as num));

    List assignments = [];
    int total = players.length;
    int pPerTable = 4;

    for (var i = 0; i < total; i += pPerTable) {
      int end = (i + pPerTable < total) ? i + pPerTable : total;
      assignments.add({
        'table': (i ~/ pPerTable) + 1,
        'players':
            players.sublist(i, end).map((p) => p['name'] as String).toList(),
      });
    }

    r['assignments'] = assignments;

    return Response.ok(jsonEncode({
      'status': 'started',
      'round': r['round'],
      'assignments': assignments
    }));
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

  await io.serve(handler, '0.0.0.0', port);
  print('Server running on port $port');
}
