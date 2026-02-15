import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  // Use your computer's IP here so other devices can connect!
  final String serverUrl = "http://192.168.1.14:8080/players";

  Future<List<String>> fetchPlayers() async {
    final response = await http.get(Uri.parse(serverUrl));
    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.cast<String>();
    } else {
      throw Exception("Server is sleeping...");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tournament Lobby"),
        actions: [
          // Refresh button to manually trigger the update
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}), 
          )
        ],
      ),
      body: FutureBuilder<List<String>>(
        future: fetchPlayers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No players joined yet..."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: CircleAvatar(child: Text("${index + 1}")),
                title: Text(snapshot.data![index]),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              );
            },
          );
        },
      ),
      // This is where you will eventually put the "START" button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Trigger the Snake Distribution algorithm!
        },
        label: const Text("Start Round 1"),
        icon: const Icon(Icons.play_arrow),
      ),
    );
  }
}