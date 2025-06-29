class UserModel {
  final String uid;
  final String email;
  final String nickname;
  final String? photoUrl;
  final String role;
  int points;
  String? currentRecipeId;
  String? currentIngredientId;
  List<String> rooms;
  List<String> completedRooms;

  UserModel({
    required this.uid,
    required this.email,
    required this.nickname,
    this.photoUrl,
    this.role = 'player',
    this.points = 0,
    this.currentRecipeId,
    this.currentIngredientId,
    this.rooms = const [],
    this.completedRooms = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'nickname': nickname,
      'photoUrl': photoUrl,
      'role': role,
      'points': points,
      'currentRecipeId': currentRecipeId,
      'currentIngredientId': currentIngredientId,
      'rooms': rooms,
      'completedRooms': completedRooms,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      email: map['email'] ?? '',
      nickname: map['nickname'] ?? '',
      photoUrl: map['photoUrl'],
      role: map['role'] ?? 'player',
      points: map['points'] ?? 0,
      currentRecipeId: map['currentRecipeId'],
      currentIngredientId: map['currentIngredientId'],
      rooms: List<String>.from(map['rooms'] ?? []),
      completedRooms: List<String>.from(map['completedRooms'] ?? []),
    );
  }

  bool isInRoom(String roomId) {
    return rooms.contains(roomId);
  }

  bool hasCompletedRoom(String roomId) {
    return completedRooms.contains(roomId);
  }

  int get activeRoomsCount => rooms.length;

  int get totalCompletedRooms => completedRooms.length;
}