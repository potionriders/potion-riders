import 'package:flutter/material.dart';
import 'package:potion_riders/models/user_model.dart';

class UserInfo extends StatelessWidget {
  final UserModel user;
  final bool showPoints;
  final VoidCallback? onTap;

  const UserInfo({super.key, 
    required this.user,
    this.showPoints = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            _buildAvatar(context),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.nickname,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (showPoints)
                    Row(
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${user.points} punti',
                          style: TextStyle(
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    if (user.photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(user.photoUrl),
        backgroundColor: Colors.grey[200],
        onBackgroundImageError: (exception, stackTrace) {
          print('Error loading avatar: $exception');
        },
      );
    }

    // Fallback se non c'è un'immagine
    return CircleAvatar(
      radius: 24,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
      child: Text(
        user.nickname.isNotEmpty ? user.nickname[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}
