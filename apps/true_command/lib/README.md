# Commander BEDH Client (Flutter)

This is the mobile frontend for the Commander BEDH Tournament Manager. It provides a real-time interface for players to track their standings and for admins to manage pods and results.

## Getting Started

### 1. Connection Setup
By default, the app looks for the server at a hardcoded IP. 
- Tap the **Gear/Edit icon** or **"Change IP"** button in the app.
- Enter the local IP address provided by the Dart Server (e.g., `192.168.1.XX`).
- Ensure your phone and the server are on the **same Wi-Fi network**.

### 2. Roles
- **Player:** Enter your name to join the lobby. You will receive real-time notifications of your table assignments.
- **Admin:** Enter the master password (default: `admin123`). Admins have the power to start rounds, roll tie-breaker rules, and report scores for all tables.

## App Structure

### State Management & Polling
The app uses a `Timer.periodic` set to **3 seconds**. 
- It fetches `/status` and `/players` continuously.
- **Auto-Sync:** If the Admin starts a round on their device, every player's phone will automatically switch from the "Lobby" view to the "Active Table" view within 3 seconds.

### Logic Flows
- **Pairing View:** Shows your Table Number and your 2-3 opponents.
- **History Tab:** A searchable log of all games played so far.
- **Podium View:** Visible only when the Admin ends the tournament; shows final rankings with Strength of Schedule (SoS) tie-breakers.



## Advanced Features

- **SoS Visibility:** The leaderboard displays "SoS" (Strength of Schedule). If two players have 10 points, the one who played against opponents with higher total scores will appear higher.
- **Random Tie-Breaker:** The Admin can tap the 🎲 icon on any table to generate a random rule (e.g., "Total Life" or "Number of Permanents") to resolve in-game draws.
- **Session Protection:** Changing the Server IP or Admin Password automatically clears the local session and returns the user to the Login screen to prevent data corruption.

## Dependencies
- `http`: For REST communication.
- `dart:async`: For the background refresh timers.
- `dart:convert`: For JSON serialization.
