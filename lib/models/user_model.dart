class UserModel {
  final String uid;
  final String email;
  final String nickname;
  final String? photoUrl; // Nota: questo è photoUrl, non avatarUrl
  final String role;
  int points;
  String? currentRecipeId;
  String? currentIngredientId;

  UserModel({
    required this.uid,
    required this.email,
    required this.nickname,
    this.photoUrl,
    this.role = 'player', // Default role è 'player'
    this.points = 0,
    this.currentRecipeId,
    this.currentIngredientId,
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
    );
  }
}
