import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';

void main() => runApp(const MaterialApp(
      home: TournamentApp(),
      debugShowCheckedModeBanner: false,
    ));

class TournamentApp extends StatefulWidget {
  const TournamentApp({super.key});
  @override
  State<TournamentApp> createState() => _TournamentAppState();
}

class _TournamentAppState extends State<TournamentApp> {
  // --- CONFIGURATION ---
  final String serverIp = "192.168.1.14"; 
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roundsController = TextEditingController(text: "3");

  // --- NEW STATE VARIABLES ---
  bool hasSelectedRole = false;
  bool isAdmin = false;
  String? loggedInUser; // To identify which player is using the phone
  String? currentAdminPassword;

  List<dynamic> players = [];
  List<dynamic> tableAssignments = [];
  List<dynamic> history = [];
  int currentRound = 0;
  int maxRounds = 3;
  int _currentIndex = 0;
  bool isFinished = false;
  Timer? _refreshTimer;

  // --- TIE BREAK LOGIC ---
String? _selectedRule;
final List<String> _tieBreakRules = [
  "Total Life",
  "Priority Order",
  "Commander Damage Inflicted",
  "Commander Damage Received",
  "Nº of Permanents [No lands/tokens]",
  "Nº of Mana Sources",
  "Number of Remaining Cards in Library",
  "Devotion to your commander"
];

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (t) => refreshLobby());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _nameController.dispose();
    _roundsController.dispose();
    super.dispose();
  }

  // --- API CALLS ---

  Future<void> downloadReport() async {
  final response = await http.get(Uri.parse('http://$serverIp:8080/export'));

    if (response.statusCode == 200) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Tournament Report Generated"),
          content: SingleChildScrollView(
            child: SelectableText(response.body), // Allows Admin to copy the text
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
            ElevatedButton(
              onPressed: () {
                // You could integrate the 'share_plus' package here 
                // to share directly to WhatsApp/Email
                Navigator.pop(context);
              },
              child: const Text("Done"),
            ),
          ],
        ),
      );
    }
  }
  Future<void> refreshLobby() async {
  try {
    final pRes = await http.get(Uri.parse('http://$serverIp:8080/players'));
    final sRes = await http.get(Uri.parse('http://$serverIp:8080/status'));
    final hRes = await http.get(Uri.parse('http://$serverIp:8080/history'));

    if (pRes.statusCode == 200 && sRes.statusCode == 200 && hRes.statusCode == 200) {
      final statusData = jsonDecode(sRes.body);
      final List<dynamic> decodedPlayers = jsonDecode(pRes.body);

      setState(() {
        // We ensure the app treats points as num (double/int)
        players = decodedPlayers;
        history = jsonDecode(hRes.body);
        
        // Update current status
        isFinished = statusData['status'] == 'finished';
        
        if (statusData['status'] == 'started') {
          tableAssignments = statusData['assignments'];
          currentRound = statusData['round'] ?? 0;
          maxRounds = statusData['maxRounds'] ?? 3;
        } else if (statusData['status'] == 'waiting') {
          tableAssignments = []; // Clear tables if back in lobby
          isFinished = false;
        }
      });
    }
  } catch (e) {
    debugPrint("Sync Error: $e");
  }
  }

  Future<void> joinTournament() async {
    if (_nameController.text.isEmpty) return;
    await http.post(
      Uri.parse('http://$serverIp:8080/join'),
      body: jsonEncode({'name': _nameController.text}),
    );
    setState(() {
      loggedInUser = _nameController.text;
      hasSelectedRole = true;
      isAdmin = false;
    });
    refreshLobby();
  }

  Future<void> reportResult(String pName, num points, int rank, int tableId) async {
  // Determine rank based on points for the history log
  int rank;
  if (points == 4) rank = 1;
  else if (points == 3 || points == 2.5) rank = 2;
  else if (points == 2) rank = 3;
  else rank = 4;

  try {
    final response = await http.post(
      Uri.parse('http://$serverIp:8080/report-result'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'name': pName,
        'points': points,
        'rank': rank,
        'table': tableId,
        'adminKey': currentAdminPassword,
      }),
    );

    if (response.statusCode == 200) {
      await refreshLobby(); // Force update the UI
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Recorded: $pName got $points pts")),
      );
    }
  } catch (e) {
    debugPrint("Report Error: $e");
  }
 }

  Future<void> startNextRound() async {
  try {
    final response = await http.post(
      Uri.parse('http://$serverIp:8080/start'),
      // ADD THIS LINE: Tells the server we are sending JSON
      headers: {"Content-Type": "application/json"}, 
      body: jsonEncode({
        'maxRounds': int.tryParse(_roundsController.text) ?? 3,
        'isAdmin': true, 
        'adminPassword': currentAdminPassword 
      }),
    ).timeout(const Duration(seconds: 5)); // Add a timeout so it doesn't hang

    if (response.statusCode == 200) {
      refreshLobby();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Round Started!"), backgroundColor: Colors.green),
      );
    } else {
      // If the password was wrong or body was malformed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Server Denied: ${response.body}"), backgroundColor: Colors.orange),
      );
    }
  } catch (e) {
    // This is the "Network Error" you are seeing
    print("Error Details: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Network Error: Is the server still running?"), backgroundColor: Colors.red),
    );
  }
  }

  Future<void> resetTournament() async {
    await http.get(Uri.parse('http://$serverIp:8080/reset'));
    setState(() {
      tableAssignments = [];
      isFinished = false;
      currentRound = 0;
    });
    refreshLobby();
  }

  Future<void> deleteHistoryEntry(Map<String, dynamic> entry) async {
  try {
    final response = await http.post(
      Uri.parse('http://$serverIp:8080/undo'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'adminPassword': currentAdminPassword,
        'playerName': entry['player'],
        'round': entry['round'],
        'pointsToRemove': 5 - (entry['rank'] as int),
      }),
    );

    if (response.statusCode == 200) {
      refreshLobby();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Entry removed and points adjusted.")),
      );
    }
  } catch (e) {
    debugPrint("Delete Error: $e");
  }
}

  void _generateRandomRule() {
  String newRule;
  do {
    newRule = _tieBreakRules[Random().nextInt(_tieBreakRules.length)];
  } while (newRule == _selectedRule); // Keep rolling until it's a different one
  
  setState(() {
    _selectedRule = newRule;
  });
}

// Confirmation Dialog to prevent accidental deletes
void _confirmDeleteEntry(dynamic log) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Delete Entry?"),
      content: Text("This will remove ${log['player']}'s result for Round ${log['round']} and subtract their points."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            Navigator.pop(context);
            deleteHistoryEntry(log);
          },
          child: const Text("Delete"),
        ),
      ],
    ),
  );
}
  // --- UI SCREENS ---

void _showAdminPasswordDialog() {
  String enteredPass = "";
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Admin Login"),
      content: TextField(
        obscureText: true,
        onChanged: (v) => enteredPass = v,
        decoration: const InputDecoration(hintText: "Server Password"),
      ),
      actions: [
        ElevatedButton(
          onPressed: () async {
            // Ask the server if this password is correct
            final response = await http.post(
              Uri.parse('http://$serverIp:8080/verify-admin'),
              body: jsonEncode({'password': enteredPass}),
            );

            if (response.statusCode == 200) {
              setState(() {
                isAdmin = true;
                hasSelectedRole = true;
                loggedInUser = "Admin";
                currentAdminPassword = enteredPass; // Save it for later!
              });
              Navigator.pop(context);
            } else {
              // Show "Wrong Password" error
            }
          },
          child: const Text("Login"),
        )
      ],
    ),
  );
}

Widget _buildTieBreakButton() {
  return Card(
    color: Colors.red.shade50,
    margin: const EdgeInsets.all(16),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          const Text("ADMIN TIE-BREAKER TOOL", 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
          const SizedBox(height: 8),
          Text(
            _selectedRule ?? "No Rule Selected",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _generateRandomRule,
            icon: const Icon(Icons.casino),
            label: const Text("Randomize Rule"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          )
        ],
      ),
    ),
  );
}

 Widget _buildRoleSelection() {
  return Scaffold(
    body: Center(
      child: SingleChildScrollView( // Added scroll view to prevent overflow on keyboard popup
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- LOGO FROM ASSETS ---
              Image.asset(
                'logo.png',
                height: 250, // Adjusted size
                width: 400,
                fit: BoxFit.contain,
                // Fallback if image isn't found during setup
                errorBuilder: (context, error, stackTrace) => 
                  const Icon(Icons.style, size: 80, color: Colors.blueGrey),
              ),
              const SizedBox(height: 20),
              
              const Text(
                "COMMANDER BEDH", 
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Enter Your Name",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: joinTournament,
                  child: const Text("Join as Player"),
                ),
              ),
              const SizedBox(height: 20),
              
              const Text("OR"),
              
              TextButton.icon(
                icon: const Icon(Icons.admin_panel_settings, color: Colors.red),
                label: const Text(
                  "Enter as Administrator", 
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: _showAdminPasswordDialog, 
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

 Widget _buildMainView() {
  if (isFinished) return _buildPodiumView();

  // 1. LOBBY VIEW
  if (tableAssignments.isEmpty) {
    return Column(
      children: [
        if (isAdmin) 
          _buildTieBreakButton(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.repeat),
                title: TextField(
                  controller: _roundsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Set Total Rounds"),
                ),
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text("Waiting for Players...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: players.length,
            itemBuilder: (context, i) {
              bool isMe = players[i]['name'] == loggedInUser;
              return ListTile(
                leading: Icon(Icons.account_circle, color: isMe ? Colors.blue : Colors.grey),
                title: Text(players[i]['name'], 
                  style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("${players[i]['points'].toString().replaceAll(RegExp(r'\.0$'), '')} pts", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("SoS: ${players[i]['sos'] ?? 0}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

 // 2. ACTIVE TABLES VIEW
  return ListView.builder(
    itemCount: tableAssignments.length,
    itemBuilder: (context, i) {
      var table = tableAssignments[i];
      int tableNumber = table['table']; // Get the table ID
      int tableSize = table['players'].length;

      return Card(
        margin: const EdgeInsets.all(10),
        child: Column(
          children: [
            ListTile(
              title: Text("TABLE $tableNumber ($tableSize Players)", 
                style: const TextStyle(fontWeight: FontWeight.bold)),
              tileColor: Colors.blueGrey.shade100,
            ),
            ...table['players'].map<Widget>((pName) {
              bool isMe = pName == loggedInUser;
              bool alreadyReported = history.any((log) => 
                log['player'] == pName && log['round'] == currentRound
              );

              return ListTile(
                title: Text(isMe ? "$pName (YOU)" : pName, 
                  style: TextStyle(
                    fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                    color: alreadyReported ? Colors.grey : Colors.black
                  )),
                trailing: isAdmin ? Wrap(
                  spacing: 4,
                  children: () {
                    final Map<int, double> scoringMap = (tableSize == 3) 
                        ? {1: 4.0, 2: 2.5, 3: 1.0} 
                        : {1: 4.0, 2: 3.0, 3: 2.0, 4: 1.0};

                    return scoringMap.entries.map((entry) {
                      int rank = entry.key;
                      double points = entry.value;

                      // CHECK: Is this specific rank already taken at THIS table in THIS round?
                      bool isRankTaken = history.any((log) => 
                        log['table'] == tableNumber && 
                        log['round'] == currentRound && 
                        log['rank'] == rank
                      );

                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(40, 38),
                          padding: EdgeInsets.zero,
                          // If rank is taken by someone else, turn it dark/grey
                          backgroundColor: alreadyReported 
                              ? Colors.grey 
                              : (isRankTaken ? Colors.black38 : _getRankColor(rank)),
                        ),
                        // Disable button if player already reported OR if rank is already taken
                        onPressed: (alreadyReported || isRankTaken) 
                            ? null 
                            : () => reportResult(pName, points, rank, tableNumber), // Pass rank and table!
                        child: isRankTaken 
                            ? const Icon(Icons.lock, size: 12, color: Colors.white70) // Show lock icon
                            : Text("$rankº", style: const TextStyle(color: Colors.white, fontSize: 11)),// Remove bracers in rank ...
                      );
                    }).toList();
                  }(),
                ) : (alreadyReported ? const Icon(Icons.check, color: Colors.green) : null),
              );
            }).toList(),
          ],
        ),
      );
    },
  );
}

  // (Keeping your original _buildPodiumView, _buildHistoryView, _getRankColor here)

  @override
  Widget build(BuildContext context) {
    if (!hasSelectedRole) return _buildRoleSelection();

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? "Admin Console" : "Tournament Info"),
        backgroundColor: isAdmin ? Colors.redAccent.shade700 : Colors.blueGrey,
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => setState(() => hasSelectedRole = false),
        ),
        actions: [
          if (isAdmin) IconButton(icon: const Icon(Icons.delete_forever), onPressed: resetTournament),
        ],
      ),
      body: _currentIndex == 0 ? _buildMainView() : _buildHistoryView(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.table_chart), label: "Tables"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
        ],
      ),
      floatingActionButton: (isAdmin && _currentIndex == 0 && !isFinished)
          ? FloatingActionButton(
              onPressed: startNextRound,
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.play_arrow),
            )
          : null,
    );
  }

  // --- COPIED HELPERS FROM ORIGINAL ---
  Color _getRankColor(int rank) {
    switch (rank) {
      case 1: return Colors.amber.shade700;
      case 2: return Colors.blueGrey.shade400;
      case 3: return Colors.brown.shade400;
      default: return Colors.grey.shade600;
    }
  }

  Widget _buildPodiumView() {
  // Sort by points for the final display
  List sorted = List.from(players);
  sorted.sort((a, b) => (b['points'] as num).compareTo(a['points'] as num));

  return Column(
    children: [
      const SizedBox(height: 20),
      const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
      const Text("FINAL STANDINGS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      Expanded(
        child: ListView.builder(
          itemCount: sorted.length,
          itemBuilder: (context, i) {
            final p = sorted[i];
            return ListTile(
              leading: CircleAvatar(child: Text("${i + 1}")),
              title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("SoS: ${p['sos']}"),
              trailing: Text("${p['points'].toString().replaceAll(RegExp(r'\.0$'), '')} Pts", 
                  style: const TextStyle(fontSize: 18, color: Colors.blue)),
            );
          },
        ),
      ),
      if (isAdmin) 
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(onPressed: downloadReport, icon: const Icon(Icons.download), label: const Text("Export")),
              ElevatedButton.icon(onPressed: resetTournament, icon: const Icon(Icons.refresh), label: const Text("Reset")),
            ],
          ),
        ),
    ],
  );
 }

 Widget _buildHistoryView() {
  if (history.isEmpty) return const Center(child: Text("No match logs yet."));
  
  return ListView.builder(
    itemCount: history.length,
    itemBuilder: (context, i) {
      final log = history[i];
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRankColor(log['rank'] ?? 4), 
          child: Text("${log['rank']}º"),
        ),
        title: Text(log['player'] ?? "Unknown"),
        subtitle: Text("Round ${log['round']}"),
        // NEW: Trailing logic to show either Time or an Undo button for Admin
        trailing: isAdmin 
          ? IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              tooltip: "Remove this entry",
              onPressed: () => _confirmDeleteEntry(log),
            )
          : Text(log['time'] ?? ""),
      );
    },
  ); 
  }
}