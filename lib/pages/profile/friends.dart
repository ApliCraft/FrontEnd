import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../widgets/bottomNavBar.dart';
import '../../widgets/navigationProfileAppBar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:decideat/api/api.dart';
import 'friend/friend_profile.dart';

class FriendsPage extends StatefulWidget {
  final String? userId;
  const FriendsPage({Key? key, this.userId}) : super(key: key);

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  List<Map<String, dynamic>> friends = [];
  List<String> myFriendIds = [];
  bool isLoading = true;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      currentUserId = await storage.read(key: 'userId');
      if (currentUserId != null) {
        final myFriendsResponse = await http.get(
          Uri.parse('$apiUrl/user/friends/get/$currentUserId'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
        );

        if (myFriendsResponse.statusCode == 200) {
          myFriendIds = List<String>.from(jsonDecode(myFriendsResponse.body));
        }
      }

      await _loadFriends();
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadFriends() async {
    try {
      final String userId = widget.userId ?? await storage.read(key: 'userId') ?? '';
      if (userId.isEmpty) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final friendsResponse = await http.get(
        Uri.parse('$apiUrl/user/friends/get/$userId'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (friendsResponse.statusCode == 200) {
        final List<dynamic> friendIds = jsonDecode(friendsResponse.body);
        List<Map<String, dynamic>> friendsData = [];

        for (String friendId in friendIds) {
          final friendResponse = await http.get(
            Uri.parse('$apiUrl/user/$friendId'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
          );

          if (friendResponse.statusCode == 200) {
            final friendData = jsonDecode(friendResponse.body);
            final String avatarLink = friendData['avatarLink'] != null && friendData['avatarLink'].toString().isNotEmpty
                ? '$apiUrl/${friendData['avatarLink']}'
                : '$apiUrl/images/default_avatar.png';
                
            friendsData.add({
              'id': friendId,
              'username': friendData['username'] ?? '',
              'avatarLink': avatarLink,
              'description': friendData['description']?.toString().isNotEmpty == true 
                  ? friendData['description'] 
                  : "User doesn't have description",
              'isFriend': myFriendIds.contains(friendId) || friendId == currentUserId,
            });
          }
        }

        setState(() {
          friends = friendsData;
          isLoading = false;
        });
      } else {
        print('Failed to load friends list');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading friends: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _addFriend(String friendId) async {
    try {
      final response = await http.put(
        Uri.parse('$apiUrl/user/friends/add-friend/$friendId'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${await storage.read(key: 'accessToken')}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          final friendIndex = friends.indexWhere((friend) => friend['id'] == friendId);
          if (friendIndex != -1) {
            friends[friendIndex]['isFriend'] = true;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend added successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add friend')),
        );
      }
    } catch (e) {
      print('Error adding friend: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error adding friend')),
      );
    }
  }

  Future<void> _unfriend(String friendId) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiUrl/user/friends/remove-friend/$friendId'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${await storage.read(key: 'accessToken')}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          final friendIndex = friends.indexWhere((friend) => friend['id'] == friendId);
          if (friendIndex != -1) {
            friends[friendIndex]['isFriend'] = false;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend removed successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove friend')),
        );
      }
    } catch (e) {
      print('Error removing friend: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error removing friend')),
      );
    }
  }

  Future<void> _showUnfriendDialog(String friendId, String friendName) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Unfriend Confirmation'),
          content: Text('Are you sure you want to unfriend $friendName?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Unfriend',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _unfriend(friendId);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: const NavigationProfileAppBar(currentPage: 'friends'),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.shade50,
              const Color.fromARGB(0, 255, 255, 255)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : friends.isEmpty
            ? Center(
                child: Text(
                  loc.noFriendsYet,
                  style: const TextStyle(fontSize: 18),
                ),
              )
            : ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) =>
                                FriendProfilePage(id: friend['id']),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            transitionDuration: const Duration(milliseconds: 300),
                          ),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundImage: NetworkImage(friend["avatarLink"]!),
                          ),
                          title: Text(
                            friend["username"]!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: friend["description"] != null && friend["description"].length > 50
                            ? Text(
                                "${friend["description"].substring(0, 50)}...",
                                style: TextStyle(color: Colors.grey),
                              )
                            : Text(
                                friend["description"] ?? "",
                                style: TextStyle(color: Colors.grey),
                              ),
                          trailing: friend['isFriend']
                            ? PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (String value) {
                                  if (value == 'chat') {
                                    // TODO: Implement chat functionality
                                  } else if (value == 'unfriend') {
                                    _showUnfriendDialog(friend['id'], friend['username']);
                                  }
                                },
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'chat',
                                    child: Row(
                                      children: [
                                        Icon(Icons.chat, color: Colors.green),
                                        SizedBox(width: 8),
                                        Text('Chat'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'unfriend',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_remove, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Unfriend'),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : IconButton(
                                icon: const Icon(Icons.person_add, color: Colors.blue),
                                onPressed: () => _addFriend(friend['id']),
                              ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
      bottomNavigationBar: const BottomNavBar(initialIndex: 4),
    );
  }
}
