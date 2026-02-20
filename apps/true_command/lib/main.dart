import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';

void main() {
  runApp(MyApp());
}

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const TournamentApp(),
    ),
    GoRoute(
      path: '/admin/:room',
      builder: (context, state) {
        final room = state.pathParameters['room'];
        return TournamentApp(initialRoom: room, forceAdmin: true);
      },
    ),
    GoRoute(
      path: '/lobby/:room',
      builder: (context, state) {
        final room = state.pathParameters['room'];
        return TournamentApp(initialRoom: room);
      },
    ),
  ],
);

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}


class TournamentApp extends StatefulWidget {
  final String? initialRoom;
  final bool forceAdmin;

  const TournamentApp({
    super.key,
    this.initialRoom,
    this.forceAdmin = false,
  });

  @override
  State<TournamentApp> createState() => _TournamentAppState();
}

class _TournamentAppState extends State<TournamentApp> {
  // --- CONFIGURATION ---
String serverUrl = "https://truecommandercompanion.onrender.com"; 
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomController = TextEditingController(); // NEW: For Room ID
  final TextEditingController _roundsController = TextEditingController(text: "3");

  bool hasSelectedRole = false;
  bool isAdmin = false;
  String? loggedInUser;
  String? roomName; // NEW: Stores the current room
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
  "Nº of Mana Sources"
];

@override
void initState() {
  super.initState();

  if (widget.initialRoom != null) {
    roomName = widget.initialRoom;
    hasSelectedRole = true;

    if (widget.forceAdmin) {
      isAdmin = true;
      loggedInUser = "Admin";
    }
  }

  _refreshTimer =
      Timer.periodic(const Duration(seconds: 3), (t) => refreshLobby());
}

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _nameController.dispose();
    //_roundsController.dispose();
    super.dispose();
  }

  bool _allResultsIn() {
    // If no round has started yet, we are ready to start Round 1
    if (tableAssignments.isEmpty) return true;

    // 1. Get a list of every player name currently assigned to a table
    List<String> assignedPlayers = [];
    for (var table in tableAssignments) {
      if (table['players'] != null) {
        assignedPlayers.addAll(List<String>.from(table['players']));
      }
    }

    // 2. Check if every one of those players exists in the history for the current round
    return assignedPlayers.every((pName) => 
      history.any((log) => log['player'] == pName && log['round'] == currentRound)
    );
  }
  // 1. Function to Change Server IP
  // 1. Revised IP Dialog
  /*void _showChangeIpDialog() {
    TextEditingController ipController = TextEditingController(text: serverIp);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update Server IP"),
        content: TextField(
          controller: ipController,
          decoration: const InputDecoration(hintText: "e.g. 192.168.1.50"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              // STOP the timer immediately to prevent background sync
              _refreshTimer?.cancel();

              setState(() {
                serverIp = ipController.text;
                // FULL RESET: This forces the build method to show _buildRoleSelection()
                hasSelectedRole = false; 
                loggedInUser = null; 
                isAdmin = false;
                tableAssignments = []; 
              });

              Navigator.pop(context); // Close dialog

              // Restart the timer for the "Front Page" if needed, 
              // or let the next login start it.
              _refreshTimer = Timer.periodic(const Duration(seconds: 3), (t) => refreshLobby());
            },
            child: const Text("Update & Logout"),
          ),
        ],
      ),
    );
  }*/

  // 2. Revised Password Dialog
  void _showChangePasswordDialog() {
    TextEditingController passController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update Admin Password"),
        content: TextField(
          controller: passController,
          obscureText: true,
          decoration: const InputDecoration(hintText: "Enter new password"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final newPass = passController.text;
              if (newPass.isNotEmpty) {
                await _sendPasswordUpdateToServer(newPass);
                
                // STOP the timer immediately
                _refreshTimer?.cancel();

                setState(() {
                  // FULL RESET to trigger _buildRoleSelection()
                  hasSelectedRole = false;
                  isAdmin = false;
                  loggedInUser = null; 
                  tableAssignments = []; 
                  currentAdminPassword = ""; 
                });

                Navigator.pop(context); // Close dialog
                
                // Restart timer for the fresh session
                _refreshTimer = Timer.periodic(const Duration(seconds: 3), (t) => refreshLobby());

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Password updated. Returning to Main Page.")),
                );
              }
            },
            child: const Text("Update & Logout"),
          ),
        ],
      ),
    );
  }

void _confirmReset() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Reset Tournament?"),
        content: const Text(
          "This will permanently delete all players, scores, and match history. Are you sure you want to proceed?"
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Close dialog
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              resetTournament();     // Execute the reset
            },
            child: const Text("RESET ALL", style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
}

void _showJoinQR() {
  // Use your actual Render URL + the lobby path
  // This makes the QR code a "clickable link" for phone cameras
  String qrData = "https://truecommandercompanion.onrender.com/lobby/$roomName";

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Invite Players to: $roomName"),
      content: SizedBox(
        width: 250,
        height: 280,
        child: Column(
          children: [
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200.0,
            ),
            const SizedBox(height: 10),
            const Text("Players can scan this to open the app and join automatically!",
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
      ],
    ),
  );
}
  // --- API CALLS ---

// Force the room name to lowercase so everyone ends up in the same room
String _baseUrl(String endpoint) => "$serverUrl/api/${roomName?.toLowerCase()}/$endpoint";

Future<void> refreshLobby() async {
    if (roomName == null) return;
    try {
      // Notice how we use the roomName in the URL now
      final pRes = await http.get(Uri.parse(_baseUrl('players')));
      final sRes = await http.get(Uri.parse(_baseUrl('status')));
      final hRes = await http.get(Uri.parse(_baseUrl('history')));

      if (pRes.statusCode == 200 && sRes.statusCode == 200 && hRes.statusCode == 200) {
        final statusData = jsonDecode(sRes.body);
        setState(() {
          players = jsonDecode(pRes.body);
          history = jsonDecode(hRes.body);
          isFinished = statusData['status'] == 'finished';
          if (statusData['status'] == 'started') {
            tableAssignments = statusData['assignments'];
            currentRound = statusData['round'] ?? 0;
          } else if (statusData['status'] == 'waiting') {
            tableAssignments = [];
            isFinished = false;
          }
        });
      }
    } catch (e) {
      debugPrint("Sync Error: $e");
    }
  }

  Future<void> joinTournament() async {
    if (_nameController.text.isEmpty || _roomController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text("Enter both Name and Room ID"))
       );
       return;
    }
    
    // Set the room name first
    roomName = _roomController.text.trim();

    await http.post(
      Uri.parse(_baseUrl('join')),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': _nameController.text}),
    );
    
    setState(() {
      loggedInUser = _nameController.text;
      hasSelectedRole = true;
      isAdmin = false;
    });
    refreshLobby();
  }

Future<void> _scanJoinCode() async {
  final String? code = await Navigator.push(
    context, 
    MaterialPageRoute(builder: (context) => const QRScannerPage())
  );

  if (code != null) {
    String scannedRoom = "";
    
    // Check if it's the new URL format
    if (code.contains("/lobby/")) {
      scannedRoom = code.split("/lobby/").last;
    } 
    // Keep support for your old format just in case
    else if (code.startsWith("COMMANDER_BEDH:")) {
      scannedRoom = code.split(":")[1];
    }

    if (scannedRoom.isNotEmpty) {
      setState(() {
        _roomController.text = scannedRoom;
        roomName = scannedRoom;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Joined Room: $scannedRoom"), backgroundColor: Colors.green),
      );
    }
  }
}
Future<void> _sendPasswordUpdateToServer(String newPass) async {
  final url = Uri.parse(_baseUrl('update-password'));
  
  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'newPassword': newPass}),
    );

    if (response.statusCode == 200) {
      print("Server password updated successfully.");
    } else {
      print("Failed to update server password: ${response.body}");
    }
  } catch (e) {
    print("Error communicating with server: $e");
  }
}

  Future<void> downloadReport() async {
  final response = await http.get(Uri.parse(_baseUrl('export')));

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

Future<void> reportResult(String pName, num points, int rank, int tableId) async {
  try {
    final response = await http.post(
      Uri.parse(_baseUrl('report-result')),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'name': pName,
        'points': points,
        'rank': rank, // Use the rank passed from the button
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
        Uri.parse(_baseUrl('start')),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'maxRounds': int.tryParse(_roundsController.text) ?? 3,
          'isAdmin': true,
          'adminPassword': currentAdminPassword
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        refreshLobby();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Round Started!"), backgroundColor: Colors.green),
        );
      } else {
        // --- NEW: Handle the JSON error message from the server ---
        String errorMessage;
        try {
          final data = jsonDecode(response.body);
          errorMessage = data['error'] ?? "Server Denied: ${response.body}";
        } catch (e) {
          // Fallback if the response isn't JSON
          errorMessage = "Server error: ${response.statusCode}";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage), 
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4), // Give them time to read the name
          ),
        );
      }
    } catch (e) {
      debugPrint("Error Details: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Network Error: Is the server still running?"), backgroundColor: Colors.red),
      );
    }
  }

 Future<void> resetTournament() async {
  try {
    final response = await http.get(Uri.parse(_baseUrl('reset')));
    
    if (response.statusCode == 200) {
      setState(() {
        tableAssignments = [];
        players = []; // Clear local players
        history = []; // Clear local history
        isFinished = false;
        currentRound = 0;
      });
      
      refreshLobby();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tournament reset successfully"),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Error: Could not reach server")),
    );
  }
}

  Future<void> deleteHistoryEntry(Map<String, dynamic> entry) async {
  try {
    final response = await http.post(
      Uri.parse(_baseUrl('undo')),
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
  setState(() {
    _selectedRule = _tieBreakRules[Random().nextInt(_tieBreakRules.length)];
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

 Color _getRankColor(int rank) {
    switch (rank) {
      case 1: return Colors.amber.shade700;
      case 2: return Colors.blueGrey.shade400;
      case 3: return Colors.brown.shade400;
      default: return Colors.grey.shade600;
    }
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
        decoration: const InputDecoration(hintText: "admin123"),
      ),
      actions: [
        ElevatedButton(
          onPressed: () async {
            // Ask the server if this password is correct
            final response = await http.post(
              Uri.parse(_baseUrl('verify-admin')),
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
                'assets/logo.png',
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
              const SizedBox(height: 30),
              
              // NEW: Room ID Field
                TextField(
                  controller: _roomController,
                  decoration: const InputDecoration(
                    labelText: "Tournament Room Name (e.g. FridayMagic)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.meeting_room),
                  ),
                ),
              const SizedBox(height: 15),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Your Player Name",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 20),

              const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: joinTournament,
                      child: const Text("Join Tournament"),
                    ),
                  ),
                  TextField(
                    controller: _roomController,
                    decoration: InputDecoration(
                      labelText: "Tournament Room Name",
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.meeting_room),
                      suffixIcon: IconButton( // ADD THIS
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _scanJoinCode, 
                      ),
                    ),
                  ),
              
             const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text("OR")),
                
                TextButton.icon(
                  icon: const Icon(Icons.admin_panel_settings, color: Colors.red),
                  label: const Text("Administer Room", style: TextStyle(color: Colors.red)),
                  onPressed: () {
                    if (_roomController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Enter a Room Name first"))
                      );
                    } else {
                      roomName = _roomController.text.trim();
                      _showAdminPasswordDialog();
                    }
                  }, 
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

  // 1. LOBBY VIEW (When no round is active)
  if (tableAssignments.isEmpty) {
    // SORTING LOGIC: Points first, then SoS as tie-breaker
    List<dynamic> sortedPlayers = List.from(players);
    sortedPlayers.sort((a, b) {
      num pA = a['points'] ?? 0;
      num pB = b['points'] ?? 0;
      int cmp = pB.compareTo(pA); // High points first
      if (cmp == 0) {
        // Tie-breaker: Higher SoS (Strength of Schedule) wins
        num sosA = a['sos'] ?? 0;
        num sosB = b['sos'] ?? 0;
        return sosB.compareTo(sosA);
      }
      return cmp;
    });

    return Column(
      children: [
        if (isAdmin) ...[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.repeat, color: Colors.blue),
                title: TextField(
                  controller: _roundsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Set Total Rounds"),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                /*TextButton.icon(
                  onPressed: _showChangeIpDialog,
                  icon: const Icon(Icons.edit_location_alt, size: 18),
                  label: const Text("Change IP"),
                ),*/
                TextButton.icon(
                    onPressed: _showJoinQR, // <--- Calls your show function
                    icon: const Icon(Icons.qr_code, color: Colors.blue),
                    label: const Text("Show QR", style: TextStyle(color: Colors.blue)),
                  ),
                TextButton.icon(
                  onPressed: _showChangePasswordDialog,
                  icon: const Icon(Icons.lock_open, color: Colors.orange),
                  label: const Text("New Password", style: TextStyle(color: Colors.orange)),
                ),
              ],
            ),
          ),
          const Divider(),
        ],

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text("Tournament Standings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),

        Expanded(
          child: ListView.builder(
            itemCount: sortedPlayers.length,
            itemBuilder: (context, i) {
              final p = sortedPlayers[i];
              bool isMe = p['name'] == loggedInUser;
              return ListTile(
                title: Text(p['name'], 
                  style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${p['points'].toString().replaceAll(RegExp(r'\.0$'), '')} pts", 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                    // REAL SOS DISPLAY
                    Text(
                      "SoS: ${p['sos'] ?? 0}", 
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontStyle: FontStyle.italic)
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 2. ACTIVE TABLES VIEW (Same as your previous code)
  return ListView.builder(
    itemCount: tableAssignments.length,
    itemBuilder: (context, i) {
      var table = tableAssignments[i];
      int tableNumber = table['table'];
      int tableSize = table['players'].length;

      return Card(
        margin: const EdgeInsets.all(10),
        child: Column(
          children: [
            ListTile(
              title: Text("TABLE $tableNumber ($tableSize Players)", 
                style: const TextStyle(fontWeight: FontWeight.bold)),
              tileColor: Colors.blueGrey.shade100,
              trailing: isAdmin ? IconButton(
                icon: const Icon(Icons.casino, color: Colors.blueGrey),
                onPressed: _generateRandomRule,
                tooltip: "Roll Tie-Breaker",
              ) : null,
            ),
            if (_selectedRule != null)
              Container(
                width: double.infinity,
                color: Colors.red.shade50,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Text(
                  "TIE-BREAKER RULE: $_selectedRule",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900),
                  textAlign: TextAlign.center,
                ),
              ),
            ...table['players'].map<Widget>((pName) {
              bool isMe = pName == loggedInUser;
              bool alreadyReported = history.any((log) => 
                log['player'] == pName && log['round'] == currentRound
              );

              return ListTile(
                title: Text(isMe ? "$pName" : pName, 
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
                      double pts = entry.value;

                      bool isRankTaken = history.any((log) => 
                        log['table'] == tableNumber && 
                        log['round'] == currentRound && 
                        log['rank'] == rank
                      );

                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(40, 38),
                          padding: EdgeInsets.zero,
                          backgroundColor: alreadyReported 
                              ? Colors.grey 
                              : (isRankTaken ? Colors.black38 : _getRankColor(rank)),
                        ),
                        onPressed: (alreadyReported || isRankTaken) 
                            ? null 
                            : () => reportResult(pName, pts, rank, tableNumber),
                        child: isRankTaken 
                            ? const Icon(Icons.lock, size: 12, color: Colors.white70) 
                            : Text("$rankº", style: const TextStyle(color: Colors.white, fontSize: 11)),
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
          if (isAdmin) IconButton(icon: const Icon(Icons.delete_forever), onPressed: _confirmReset),
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
              // If results are missing, show a SnackBar instead of calling the API
              onPressed: _allResultsIn() 
                  ? startNextRound 
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Cannot start next round: Some players haven't reported results!"),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    },
              // Visual cue: Red for "Go", Grey for "Wait"
              backgroundColor: _allResultsIn() ? Colors.redAccent : Colors.grey,
              child: const Icon(Icons.play_arrow),
            )
          : null,
    );
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
// --- PLACE THIS AT THE VERY END OF YOUR FILE ---

class QRScannerPage extends StatelessWidget {
  const QRScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Tournament Code'),
        backgroundColor: Colors.blueGrey,
      ),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              // This sends the text from the QR back to the _scanJoinCode function
              Navigator.pop(context, barcode.rawValue); 
              break;
            }
          }
        },
      ),
    );
  }
}