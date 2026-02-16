import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/user_avatar.dart';
import '../services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/translations.dart';
import '../models/booking.dart';
import '../models/chat_message.dart';
import '../models/ride.dart';
import '../repositories/booking_repository.dart';
import '../repositories/chat_repository.dart';
import '../repositories/ride_repository.dart';
import '../repositories/user_repository.dart';

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
      final message = ChatMessage(
        id: '',
        text: text,
        senderId: currentUserId,
        timestamp: null,
      );
      await ChatRepository().sendMessage(widget.bookingId, message);
      
      // Notify Other User
      NotificationService.sendNotification(
        receiverId: widget.otherUserId,
        title: Translations.getText(context, 'new_message_title'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${Translations.getText(context, 'error_prefix')} $e")),
      );
    }
  }

  void _deleteMessage(String messageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Translations.getText(context, 'delete')),
        content: Text(Translations.getText(context, 'delete_message_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Translations.getText(context, 'cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ChatRepository().deleteMessage(widget.bookingId, messageId);
            }, 
            child: Text(
              Translations.getText(context, 'delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      )
    );
  }

  void _callUser() async {
    try {
      final phone = await UserRepository().fetchPhoneNumber(widget.otherUserId);
      if (phone != null && phone.isNotEmpty) {
         final Uri url = Uri.parse("tel:$phone");
         if (await canLaunchUrl(url)) {
           await launchUrl(url);
         } else {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Translations.getText(context, 'action_impossible'))));
         }
      } else {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Translations.getText(context, 'number_unavailable'))));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${Translations.getText(context, 'error_prefix')} $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<Booking?>(
          stream: BookingRepository().streamBooking(widget.bookingId),
          builder: (context, snapshot) {
            String? photoUrl = widget.otherUserPhotoUrl;
            String name = widget.otherUserName;

            final booking = snapshot.data;
            if (booking != null) {
              if (booking.driverId == widget.otherUserId) {
                photoUrl = booking.driverPhotoUrl;
                name = booking.driverName ?? name;
              } else if (booking.passengerId == widget.otherUserId) {
                 photoUrl = booking.passengerPhotoUrl;
                 name = booking.passengerName;
              }

              // Fallback if photo missing
              if (photoUrl == null || photoUrl.isEmpty) {
                 return StreamBuilder<Ride?>(
                   stream: RideRepository().streamRide(booking.rideId),
                   builder: (context, rideSnap) {
                     final ride = rideSnap.data;
                     if (ride != null && booking.driverId == widget.otherUserId) {
                        photoUrl = ride.driverPhotoUrl;
                     }
                     return Row(
                      children: [
                        UserAvatar(
                          userName: name,
                          imageUrl: photoUrl,
                          radius: 18,
                          backgroundColor: scheme.primary.withOpacity(0.18),
                          textColor: scheme.onPrimary,
                          fontSize: 14,
                        ),
                        const SizedBox(width: 10),
                        Text(name, style: const TextStyle(fontSize: 18, color: Colors.white)),
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
                  backgroundColor: scheme.primary.withOpacity(0.18),
                  textColor: scheme.onPrimary,
                  fontSize: 14,
                ),
                const SizedBox(width: 10),
                Text(name, style: const TextStyle(fontSize: 18, color: Colors.white)),
              ],
            );
          }
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: _callUser,
          ),
        ],
      ),
      body: Container(
        color: scheme.background, // Light Chat Background
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: ChatRepository().streamMessages(widget.bookingId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 10),
                          Text(
                            "${Translations.getText(context, 'say_hello')} ${widget.otherUserName} 👋",
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                    }
                  });

                  final messages = snapshot.data!;

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final bool isMe = msg.senderId == currentUserId;
                      final String text = msg.text;
                      final DateTime? ts = msg.timestamp;
                      final String time = ts != null ? DateFormat('HH:mm').format(ts) : '...';

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: InkWell(
                          onLongPress: isMe ? () => _deleteMessage(msg.id) : null,
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              gradient: isMe 
                                  ? LinearGradient(colors: [scheme.primary, scheme.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight)
                                  : null,
                              color: isMe ? null : scheme.surface,
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
                                    color: isMe ? Colors.white : scheme.onSurface,
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
                                        color: isMe ? Colors.white70 : scheme.onSurfaceVariant,
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
                color: scheme.surface,
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, -2))
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: scheme.outline),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: Translations.getText(context, 'write_message_hint'),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          hintStyle: TextStyle(color: scheme.onSurfaceVariant),
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
                      backgroundColor: scheme.primary,
                      child: Icon(Icons.send_rounded, color: scheme.onPrimary, size: 22),
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



