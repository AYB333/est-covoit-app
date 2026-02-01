import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'user_avatar.dart';
import 'notification_service.dart';

class ChatScreen extends StatefulWidget {
  final String bookingId;
  final String otherUserName;
  final String otherUserId;
  final String? otherUserPhotoUrl;

  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.otherUserName,
    required this.otherUserId,
    this.otherUserPhotoUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();

    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .collection('messages')
          .add({
        'text': text,
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Notify Other User
      NotificationService.sendNotification(
        receiverId: widget.otherUserId,
        title: "Nouveau message",
        body: text,
        type: "chat_message",
      );
      
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    }
  }

  void _deleteMessage(String messageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer"),
        content: const Text("Supprimer ce message pour tout le monde ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('bookings')
                  .doc(widget.bookingId)
                  .collection('messages')
                  .doc(messageId)
                  .delete();
            }, 
            child: const Text("Supprimer", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).snapshots(),
          builder: (context, snapshot) {
            String? photoUrl = widget.otherUserPhotoUrl;
            String name = widget.otherUserName;

            if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              if (data['driverId'] == widget.otherUserId) {
                photoUrl = data['driverPhotoUrl'];
                name = data['driverName'] ?? name;
              } else if (data['passengerId'] == widget.otherUserId) {
                 photoUrl = data['passengerPhotoUrl'];
                 name = data['passengerName'] ?? name;
              }
              
              // Fallback if photo missing
              if (photoUrl == null || photoUrl!.isEmpty) {
                 return StreamBuilder<DocumentSnapshot>(
                   stream: FirebaseFirestore.instance.collection('rides').doc(data['rideId']).snapshots(),
                   builder: (context, rideSnap) {
                     if (rideSnap.hasData && rideSnap.data != null && rideSnap.data!.exists) {
                       final rideData = rideSnap.data!.data() as Map<String, dynamic>;
                       // Only use if it matches the other user (Driver)
                       if (data['driverId'] == widget.otherUserId) {
                          photoUrl = rideData['driverPhotoUrl'];
                       }
                     }
                     return Row(
                      children: [
                        UserAvatar(
                          userName: name,
                          imageUrl: photoUrl,
                          radius: 18,
                          backgroundColor: Colors.white24,
                          textColor: Colors.white,
                          fontSize: 14,
                        ),
                        const SizedBox(width: 10),
                        Text(name, style: const TextStyle(fontSize: 18)),
                      ],
                    );
                   }
                 );
              }
            }

            return Row(
              children: [
                UserAvatar(
                  userName: name,
                  imageUrl: photoUrl,
                  radius: 18,
                  backgroundColor: Colors.white24,
                  textColor: Colors.white,
                  fontSize: 14,
                ),
                const SizedBox(width: 10),
                Text(name, style: const TextStyle(fontSize: 18)),
              ],
            );
          }
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Container(
        color: const Color(0xFFF2F5F8), // Light Chat Background
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('bookings')
                    .doc(widget.bookingId)
                    .collection('messages')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 10),
                          Text("Dites bonjour à ${widget.otherUserName} 👋", style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                    }
                  });

                  final messages = snapshot.data!.docs;

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final doc = messages[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final bool isMe = data['senderId'] == currentUserId;
                      final String text = data['text'] ?? '';
                      final Timestamp? ts = data['timestamp'] as Timestamp?;
                      final String time = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : '...';

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: InkWell(
                          onLongPress: isMe ? () => _deleteMessage(doc.id) : null,
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              gradient: isMe 
                                  ? LinearGradient(colors: [Colors.blue[700]!, Colors.blue[500]!], begin: Alignment.topLeft, end: Alignment.bottomRight)
                                  : null,
                              color: isMe ? null : Colors.white,
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 3, offset: const Offset(0, 1))
                              ],
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: isMe ? const Radius.circular(18) : Radius.zero,
                                bottomRight: isMe ? Radius.zero : const Radius.circular(18),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  text,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black87,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      time,
                                      style: TextStyle(
                                        color: isMe ? Colors.white70 : Colors.grey[500],
                                        fontSize: 10,
                                      ),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.done_all, size: 12, color: Colors.white70),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            
            // Input Area
            Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 15),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, -2))
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: "Écrire un message...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.blue[700],
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
