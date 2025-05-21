import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:potion_riders/models/room_model.dart';

class RoomCard extends StatelessWidget {
  final RoomModel room;
  final String? currentUserId;
  final VoidCallback? onTap;

  const RoomCard({super.key, 
    required this.room,
    this.currentUserId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isHost = room.hostId == currentUserId;
    final bool isParticipant =
        room.participants.any((p) => p.userId == currentUserId);
    final bool hasConfirmed = isParticipant &&
        room.participants
            .firstWhere((p) => p.userId == currentUserId)
            .hasConfirmed;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      color: room.isCompleted
          ? Colors.green.shade50
          : (isHost || isParticipant ? Colors.blue.shade50 : null),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Stanza #${room.id.substring(0, 6)}...',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(context),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ricetta:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('ID: ${room.recipeId.substring(0, 6)}...'),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Creata il:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(_formatDateTime(room.createdAt)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Partecipanti (${room.participants.length}/3):',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ...room.participants.map((participant) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        Icon(
                          participant.hasConfirmed
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 16,
                          color: participant.hasConfirmed
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ID: ${participant.userId.substring(0, 6)}...',
                          style: TextStyle(
                            fontWeight: participant.userId == currentUserId
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (participant.userId == currentUserId)
                          const Text(
                            ' (Tu)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                      ],
                    ),
                  )),
              if (isHost || isParticipant) ...[
                const SizedBox(height: 12),
                _buildParticipationStatus(context, isHost, hasConfirmed),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    if (room.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 16,
              color: Colors.white,
            ),
            SizedBox(width: 4),
            Text(
              'Completata',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final bool isReady = room.participants.length >= 3 &&
        room.participants.every((p) => p.hasConfirmed);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isReady ? Colors.amber : Colors.orange,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isReady ? Icons.done_all : Icons.people,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            isReady ? 'Pronta' : '${room.participants.length}/3',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipationStatus(
      BuildContext context, bool isHost, bool hasConfirmed) {
    if (isHost) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Row(
          children: [
            Icon(
              Icons.science,
              size: 20,
              color: Colors.blue.shade800,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sei tu il creatore di questa stanza',
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (hasConfirmed) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              size: 20,
              color: Colors.green.shade800,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Hai confermato la tua partecipazione',
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(
          children: [
            Icon(
              Icons.pending,
              size: 20,
              color: Colors.orange.shade800,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Devi ancora confermare la tua partecipazione',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    return formatter.format(dateTime);
  }
}
