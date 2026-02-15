class Player {
  final String id;
  final String name;
  final String deckList;
  
  // Basic Swiss Scoring
  int matchPoints; // 3 for Win, 1 for Draw, 0 for Loss
  int gamesPlayed;

  // The 8 Tie-Breaker Attributes
  int lifeTotal;               // Rule 1: Total Life
  int turnOrder;               // Rule 2: Priority Order (Position 1-4)
  int commanderDamageDealt;    // Rule 3: Inflicted
  int commanderDamageReceived; // Rule 4: Received
  int nonLandPermanentCount;   // Rule 5: Board Presence
  int manaSourceCount;         // Rule 6: Rocks/Dorks/Land-equivalents
  int cardsInLibrary;          // Rule 7: Deck count
  int devotionToCommander;     // Rule 8: Color symbols on board

  Player({
    required this.id,
    required this.name,
    required this.deckList,
    this.matchPoints = 0,
    this.gamesPlayed = 0,
    this.lifeTotal = 40,
    this.turnOrder = 0,
    this.commanderDamageDealt = 0,
    this.commanderDamageReceived = 0,
    this.nonLandPermanentCount = 0,
    this.manaSourceCount = 0,
    this.cardsInLibrary = 99,
    this.devotionToCommander = 0,
  });

  // This will help later when sending data to your web server
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'deckList': deckList,
    'matchPoints': matchPoints,
    'lifeTotal': lifeTotal,
    // ... we will add the rest as the API grows
  };
}