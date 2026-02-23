import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb

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
  final TextEditingController _roomController = TextEditingController(); 
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _roundsController = TextEditingController(text: "3");

  bool hasSelectedRole = false;
  bool isAdmin = false;
  String? loggedInUser;
  String? roomName; 
  String? currentAdminPassword;

  List<dynamic> players = [];
  List<dynamic> tableAssignments = [];
  List<dynamic> history = [];
  int currentRound = 0;
  int _currentIndex = 0; 
  bool isFinished = false;
  Timer? _refreshTimer;
  String _searchQuery = "";
  String? _selectedRule;

  // --- TIE BREAK LOGIC ---
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
    _roomController.dispose(); // Add this
    _passwordController.dispose(); // Add this
    _roundsController.dispose(); // Uncomment this
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

void _showTableResultDialog(int tableId, List<String> tablePlayers) {
  // Logic: {Rank: PlayerName}
  Map<int, String?> assignments = {1: null, 2: null, 3: null, 4: null};

  showDialog(
    context: context,
    barrierDismissible: false, // Prevent accidental closing
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text("Table $tableId Assignments"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [1, 2, 3, 4].map((rank) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: "Rank $rank",
                    filled: true,
                    fillColor: _getRankColor(rank).withOpacity(0.1),
                    border: const OutlineInputBorder(),
                  ),
                  value: assignments[rank],
                  items: tablePlayers.map((p) {
                    // BLOCKING LOGIC: Disable name if picked in a DIFFERENT dropdown
                    bool isAlreadyPickedElsewhere = assignments.entries.any((entry) => entry.key != rank && entry.value == p);
                    
                    return DropdownMenuItem(
                      value: p,
                      enabled: !isAlreadyPickedElsewhere,
                      child: Text(p, style: TextStyle(
                        color: isAlreadyPickedElsewhere ? Colors.grey : Colors.black
                      )),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() => assignments[rank] = val);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            // Only enable if all 4 ranks have a unique player assigned
            onPressed: assignments.values.any((v) => v == null) 
              ? null 
              : () async {
                  Navigator.pop(context);
                  for (var entry in assignments.entries) {
                    double pts = (5 - entry.key).toDouble();
                    await reportResult(entry.value!, pts, entry.key, tableId);
                  }
                },
            child: const Text("Save Table"),
          ),
        ],
      ),
    ),
  );
}

void _showBulkPasteDialog() {
  TextEditingController pasteController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Paste Player List"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Paste names separated by lines or commas:", 
            style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          TextField(
            controller: pasteController,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: "Player 1\nPlayer 2\nPlayer 3...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            final rawText = pasteController.text;
            if (rawText.isNotEmpty) {
              // Splits by new lines OR commas
              List<String> names = rawText
                  .split(RegExp(r'[\n\r,]+')) 
                  .map((name) => name.trim())
                  .where((name) => name.isNotEmpty)
                  .toList();

              Navigator.pop(context); // Close dialog
              
              _showSnackBar("Adding ${names.length} players...", Colors.blue);

              for (var name in names) {
                await addPlayerToServer(name);
              }
              
              _showSnackBar("Bulk add complete!", Colors.green);
            }
          },
          child: const Text("Add All"),
        ),
      ],
    ),
  );
}


void massAddPlayers(String rawNames) {
  // Split by newline or comma, trim whitespace, and remove empty lines
  List<String> newNames = rawNames
      .split(RegExp(r'[\n,]'))
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toList();

  setState(() {
    for (var name in newNames) {
      if (players.length < 64 && !players.contains(name)) {
        players.add(name);
      }
    }
  });
}

void _handleEntry() async {
  final room = _roomController.text.trim();
  final pass = _passwordController.text.trim();

  if (room.isEmpty) {
    _showSnackBar("Please enter a Tournament ID", Colors.red);
    return;
  }

  roomName = room;

  if (pass.isNotEmpty) {
    // Attempt Admin Login
    try {
      final response = await http.post(
        Uri.parse(_baseUrl('verify-admin')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'password': pass}),
      );

      if (response.statusCode == 200) {
        setState(() {
          isAdmin = true;
          hasSelectedRole = true;
          loggedInUser = "Admin";
          currentAdminPassword = pass;
        });
        refreshLobby();
      } else {
        _showSnackBar("Invalid Admin Password", Colors.orange);
      }
    } catch (e) {
      _showSnackBar("Connection error", Colors.red);
    }
  } else {
    // ENTER AS GUEST/VIEWER
    setState(() {
      isAdmin = false;
      hasSelectedRole = true;
      loggedInUser = "Viewer"; // No name needed for guests
    });
    refreshLobby();
  }
}

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
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

Future<void> _finishTournament() async {
  try {
    final response = await http.post(
      Uri.parse(_baseUrl('finish-tournament')),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({'adminPassword': currentAdminPassword}),
    );

    if (response.statusCode == 200) {
      setState(() {
        isFinished = true;
      });
      _showSnackBar("Tournament Highly Successful! Checking final scores...", Colors.yellowAccent);
    }
  } catch (e) {
    _showSnackBar("Error finishing tournament", Colors.red);
  }
}

  Future<void> pickRosterFile() async {
  if (roomName == null) return; // Safety check
  
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result != null) {
      String content = "";
      if (kIsWeb) {
        final bytes = result.files.first.bytes;
        if (bytes != null) content = utf8.decode(bytes); // Better for UTF-8 names
      } else {
        final file = File(result.files.single.path!);
        content = await file.readAsString();
      }

      List<String> names = content
          .split(RegExp(r'[\n\r]'))
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toList();

      for (var name in names) {
        await addPlayerToServer(name);
      }

      _showSnackBar("Successfully added ${names.length} players!", Colors.green);
    }
  } catch (e) {
    _showSnackBar("Failed to read file.", Colors.red);
  }
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
  // If we just finished Round 3, we should close the tournament instead of starting Round 4
  if (currentRound >= 3) {
    _finishTournament();
    return;
  }

  try {
    final response = await http.post(
      Uri.parse(_baseUrl('next-round')),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({'adminPassword': currentAdminPassword}),
    );

    if (response.statusCode == 200) {
      _showSnackBar("Round ${currentRound + 1} Started!", Colors.green);
      await refreshLobby(); // This will update currentRound locally
    }
  } catch (e) {
    _showSnackBar("Error starting next round", Colors.red);
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

Future<void> addPlayerToServer(String name) async {
  try {
    await http.post(
      Uri.parse(_baseUrl('join')),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    refreshLobby(); // Update the list immediately
  } catch (e) {
    debugPrint("Add Player Error: $e");
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

Future<void> removePlayerFromServer(String name) async {
  try {
    final response = await http.post(
      Uri.parse(_baseUrl('remove-player')),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'name': name,
        'adminPassword': currentAdminPassword,
      }),
    );
    
    if (response.statusCode == 200) {
      // Option A: Force an immediate local UI update
      setState(() {
        players.removeWhere((p) => p['name'] == name);
      });
      
      // Option B: Sync with server to ensure everything is perfect
      await refreshLobby(); 
      
      _showSnackBar("Player $name removed", Colors.green);
    } else {
      _showSnackBar("Failed to remove player", Colors.red);
    }
  } catch (e) {
    debugPrint("Remove Error: $e");
  }
}

void _confirmRemovePlayer(String name) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Remove Player?"),
      content: Text("Do you want to remove $name? They will not be paired in future rounds."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () {
            removePlayerFromServer(name);
            Navigator.pop(context);
          },
          child: const Text("Remove"),
        ),
      ],
    ),
  );
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

Widget _buildRoleSelection() {
  return Scaffold(
    backgroundColor: Colors.grey[50],
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Visual Header
              Container(
                padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/logo.png', // Ensure this matches your file name exactly
                    width: 250,        // Adjust width to fit your design
                    height: 200,       // Adjust height to fit your design
                    fit: BoxFit.contain,
                    // This part prevents the app from crashing if you haven't 
                    // added the image to pubspec.yaml yet:
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.shield_moon, size: 80, color: Colors.blueAccent);
                    },
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                "COMMANDER BEDH", 
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const Text("Enter ID to view or Password to manage"),
              const SizedBox(height: 40),
              
              // Tournament ID (Room)
              TextField(
                controller: _roomController,
                decoration: InputDecoration(
                  labelText: "Tournament ID",
                  hintText: "e.g., friday_night_magic",
                  prefixIcon: const Icon(Icons.grid_view_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Admin Password
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Admin Password",
                  hintText: "Leave blank to enter as viewer",
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 32),

              // Single Entry Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _handleEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text("ENTER TOURNAMENT", 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
              
              const Text("— OR —", style: TextStyle(color: Colors.grey)),
              
              // QR Scan
              TextButton.icon(
                onPressed: _scanJoinCode,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("Scan QR Code"),
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
    List<dynamic> sortedPlayers = List.from(players);
    sortedPlayers.sort((a, b) {
      num pA = a['points'] ?? 0;
      num pB = b['points'] ?? 0;
      int cmp = pB.compareTo(pA);
      if (cmp == 0) {
        num sosA = a['sos'] ?? 0;
        num sosB = b['sos'] ?? 0;
        return sosB.compareTo(sosA);
      }
      return cmp;
    });

    return ListView(
      children: [
        if (isAdmin) ...[
          // --- Round Settings ---
          Card(
            margin: const EdgeInsets.all(16.0),
            child: ListTile(
              leading: const Icon(Icons.repeat, color: Colors.blue),
              title: TextField(
                controller: _roundsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Set Total Rounds"),
              ),
            ),
          ),
          
          // --- Admin Actions ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: _showJoinQR,
                icon: const Icon(Icons.qr_code, color: Colors.blue),
                label: const Text("Show QR"),
              ),
              TextButton.icon(
                onPressed: _showChangePasswordDialog,
                icon: const Icon(Icons.lock_open, color: Colors.orange),
                label: const Text("New Password"),
              ),
            ],
          ),
          const Divider(),

         // --- Manage Players Expansion ---
          ExpansionTile(
            leading: const Icon(Icons.people_outline),
            title: Text("Manage Players (${players.length}/64)"),
            children: [
              // Two buttons side-by-side for File and Paste
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // File Upload Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: pickRosterFile,
                        icon: const Icon(Icons.upload_file),
                        label: const Text("File (.txt)"),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
                      ),
                    ),
                    const SizedBox(width: 8), // Gap between buttons
                    // Bulk Paste Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showBulkPasteDialog, // Calls the dialog function
                        icon: const Icon(Icons.content_paste),
                        label: const Text("Paste List"),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search player name...",
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              
              // Manual Add Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(hintText: "Add late player..."),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_add, color: Colors.green),
                      onPressed: () {
                        if (_nameController.text.isNotEmpty && players.length < 64) {
                          addPlayerToServer(_nameController.text.trim());
                          _nameController.clear();
                          setState(() => _searchQuery = "");
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),
              
              // Player List (Keep your existing .where...map logic here)
              ...players
                  .where((p) => p['name']
                      .toString()
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()))
                  .map((p) => ListTile(
                        key: ValueKey(p['name']), // Helps Flutter track the item during deletion
                        dense: true,
                        title: Text(p['name']),
                        trailing: IconButton(
                          icon: const Icon(Icons.person_remove, color: Colors.red, size: 20),
                          onPressed: () => _confirmRemovePlayer(p['name']),
                        ),
                      ))
                  //.toList(),
            ],
          ),
        ],

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text("Tournament Standings", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),

        ...List.generate(sortedPlayers.length, (i) {
          final p = sortedPlayers[i];
          bool isMe = p['name'] == loggedInUser;
          return ListTile(
            leading: CircleAvatar(child: Text("${i + 1}")),
            title: Text(p['name'], 
              style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("${p['points'].toString().replaceAll(RegExp(r'\.0$'), '')} pts", 
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("SoS: ${p['sos'] ?? 0}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          );
        }),
        const SizedBox(height: 80),
      ],
    );
  }

  // 2. ACTIVE TABLES VIEW
  return Column(
    children: [
      // Tie-Breaker Banner
      if (_selectedRule != null)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            children: [
              const Text("ACTIVE TIE-BREAKER RULE", 
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Text(_selectedRule!, 
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (isAdmin) 
                TextButton(
                  onPressed: () => setState(() => _selectedRule = null),
                  child: const Text("Clear Rule", style: TextStyle(color: Colors.red)),
                )
            ],
          ),
        ),

      // Tables List with Scoring
      Expanded(
  child: ListView.builder(
    itemCount: tableAssignments.length,
    itemBuilder: (context, i) {
      var table = tableAssignments[i];
      int tableNumber = table['table'];
      List<String> tablePlayers = List<String>.from(table['players']);

      // Check if the WHOLE table is finished
      bool tableDone = tablePlayers.every((p) => 
        history.any((log) => log['player'] == p && log['round'] == currentRound)
      );

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          children: [
            ListTile(
              title: Text("TABLE $tableNumber", 
                style: const TextStyle(fontWeight: FontWeight.bold)),
              tileColor: tableDone ? Colors.green.shade50 : Colors.blueGrey.shade100,
              trailing: isAdmin ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Random Rule Icon
                  IconButton(
                    icon: const Icon(Icons.casino, color: Colors.blueGrey),
                    onPressed: _generateRandomRule,
                  ),
                  // THE NEW REPORT BUTTON
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tableDone ? Colors.grey : Colors.blueAccent,
                    ),
                    onPressed: tableDone ? null : () => _showTableResultDialog(tableNumber, tablePlayers),
                    child: Text(tableDone ? "Finished" : "Report Results"),
                  ),
                ],
              ) : null,
            ),
            ...tablePlayers.map<Widget>((pName) {
              bool isMe = pName == loggedInUser;
              
              // Find this specific player's rank in history if it exists
              var playerLog = history.firstWhere(
                (log) => log['player'] == pName && log['round'] == currentRound,
                orElse: () => null,
              );

              return ListTile(
                title: Text(pName, 
                  style: TextStyle(
                    fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                    color: playerLog != null ? Colors.grey : Colors.black
                  )),
                trailing: playerLog != null 
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getRankColor(playerLog['rank']),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text("${playerLog['rank']}º", style: const TextStyle(color: Colors.white)),
                    )
                  : const Icon(Icons.pending_outlined, color: Colors.orange),
              );
              })//.toList(),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}


@override
Widget build(BuildContext context) {
  // 1. If we haven't logged in/selected a room yet
  if (!hasSelectedRole) return _buildRoleSelection();

  return Scaffold(
    appBar: AppBar(
      title: Text(isAdmin ? "Admin Console" : "Tournament Info"),
      backgroundColor: isAdmin ? Colors.redAccent.shade700 : Colors.blueGrey,
      leading: IconButton(
        icon: const Icon(Icons.logout),
        onPressed: () {
          setState(() {
            hasSelectedRole = false;
            isAdmin = false;
          });
        },
      ),
      actions: [
        if (isAdmin) IconButton(
          icon: const Icon(Icons.delete_forever), 
          onPressed: _confirmReset
        ),
      ],
    ),
    
    // 2. The Body: If the tournament is finished, show the Podium. 
    // Otherwise, toggle between Tables and History.
    body: isFinished 
        ? _buildPodiumView() 
        : (_currentIndex == 0 ? _buildMainView() : _buildHistoryView()),

    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.table_chart), label: "Tables"),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
      ],
    ),

    // 3. Floating Action Button: Changes behavior based on the Round
    floatingActionButton: (isAdmin && _currentIndex == 0 && !isFinished)
        ? FloatingActionButton(
            onPressed: _allResultsIn() 
                ? startNextRound // This function now handles the 3-round limit logic
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Cannot proceed: Some tables haven't finished!"),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
            backgroundColor: _allResultsIn() ? Colors.redAccent : Colors.grey,
            child: Icon(currentRound >= 3 ? Icons.emoji_events : Icons.play_arrow),
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