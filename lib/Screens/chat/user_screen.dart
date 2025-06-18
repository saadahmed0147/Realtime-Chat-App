import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:realtime_chat_system/Screens/Chat/chat_screen.dart';
import 'package:realtime_chat_system/Screens/auth/login_screen.dart';

class UsersScreen extends StatefulWidget {
  final String currentUserId;

  const UsersScreen({required this.currentUserId, super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String userName = 'User';

  @override
  void initState() {
    super.initState();
    fetchUserName();
  }

  Future<void> fetchUserName() async {
    try {
      final userRef = FirebaseDatabase.instance.ref().child(
        'users/${widget.currentUserId}',
      );
      final snapshot = await userRef.get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          userName = data['name'] ?? 'User';
        });
      }
    } catch (e) {
      print('Error fetching username: $e');
    }
  }

  Future<String> fetchLastMessage(String otherUserId) async {
    final ids = [widget.currentUserId, otherUserId]..sort();
    final chatId = ids.join('_');

    final messagesRef = FirebaseDatabase.instance
        .ref()
        .child('chats/$chatId/messages')
        .orderByChild('timestamp')
        .limitToLast(1);

    final snapshot = await messagesRef.get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final lastMessage = data.values.first as Map;
      return lastMessage['text'] ?? '';
    }

    return 'No messages yet';
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersRef = FirebaseDatabase.instance.ref().child('users');

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $userName'),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            tooltip: "Logout",
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: usersRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error occurred"));
          if (snapshot.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());

          final data = snapshot.data?.snapshot.value as Map?;
          if (data == null) return Center(child: Text("No users found"));

          final users = data.entries
              .where((entry) => entry.key != widget.currentUserId)
              .toList();

          return ListView(
            children: users.map((entry) {
              final user = Map<String, dynamic>.from(entry.value);

              return ListTile(
                leading: CircleAvatar(
                  child: Text(user['name'][0].toUpperCase()),
                ),
                title: Text(user['name']),
                subtitle: FutureBuilder<String>(
                  future: fetchLastMessage(user['uid']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Text('Loading...');
                    } else if (snapshot.hasError) {
                      print(snapshot.error);
                      return Text('Error loading message');
                    } else {
                      return Text(snapshot.data ?? '');
                    }
                  },
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      currentUserId: widget.currentUserId,
                      otherUserId: user['uid'],
                      otherUserName: user['name'],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
