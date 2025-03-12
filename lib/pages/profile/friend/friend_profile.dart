import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../widgets/bottomNavBar.dart';
import 'friendNavigationAppBar.dart';
import 'package:decideat/api/api.dart';
import 'package:http/http.dart' as http;
import 'package:decideat/widgets/loading_widget.dart';

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class FriendProfilePage extends StatefulWidget {
  final String id;
  const FriendProfilePage({Key? key, required this.id}) : super(key: key);

  @override
  State<FriendProfilePage> createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  bool _disableParentScroll = false;
  final ScrollController _verticalScrollController = ScrollController();
  String username = '';
  String _avatarLink = '$apiUrl/images/default_avatar.png';
  List roles = [];
  String description = '';
  DateTime signInDate = DateTime.utc(0, 0, 0);
  int friendsCount = 0;
  int likedRecipesCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getProfileData();
  }

  Future<void> _getProfileData() async {
    final response = await http.get(
      Uri.parse('$apiUrl/user/${widget.id}'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        signInDate = DateTime.parse(data['signInDate'] ?? '1970-01-01');
        username = data['username'] ?? '';
        _avatarLink = data['avatarLink'] != null && data['avatarLink'].toString().isNotEmpty
            ? '$apiUrl/${data['avatarLink']}'
            : '$apiUrl/images/default_avatar.png';
        roles = data['roles'] ?? [];
        description = data['description']?.toString().isNotEmpty == true
            ? data['description']
            : "User doesn't have description";
        friendsCount = data['friendsList'] ?? 0;
        likedRecipesCount = data['likedRecipes'] ?? 0;
        _isLoading = false;
      });
    } else {
      print('Failed to load profile data');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildDishCard(String dishName, String imagePath) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              dishName,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDishList() {
    final ScrollController dishScrollController = ScrollController();
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        VerticalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
          () => VerticalDragGestureRecognizer(),
          (VerticalDragGestureRecognizer instance) {
            instance.onUpdate = (DragUpdateDetails details) {
              final newOffset = dishScrollController.offset + details.delta.dy;
              if (dishScrollController.hasClients) {
                dishScrollController.jumpTo(newOffset);
              }
            };
            instance.onStart = (_) {};
            instance.onEnd = (_) {};
          },
        ),
      },
      behavior: HitTestBehavior.opaque,
      child: Listener(
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            final newOffset =
                dishScrollController.offset + pointerSignal.scrollDelta.dy;
            if (dishScrollController.hasClients) {
              dishScrollController.jumpTo(newOffset);
            }
          }
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) => true,
          child: ScrollConfiguration(
            behavior: MyCustomScrollBehavior(),
            child: ListView.builder(
              controller: dishScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: 5,
              itemBuilder: (context, index) {
                return _buildDishCard(
                  "Dish ${index + 1}",
                  'assets/default_avatar.png',
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: FriendNavigationAppBar(
        currentPage: 'profile',
        friendId: widget.id,
      ),
      body: !_isLoading
          ? Container(
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
              child: ScrollConfiguration(
                behavior:
                    ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  physics: _disableParentScroll
                      ? const NeverScrollableScrollPhysics()
                      : const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage(_avatarLink),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        description.isEmpty ? loc.profileDescription : description,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStat(loc.recipes, likedRecipesCount.toString()),
                          _buildStat(loc.friends, friendsCount.toString()),
                          _buildStat(
                            loc.joined,
                            signInDate
                                .toString()
                                .split(' ')[0]
                                .replaceAll('-', '/'),
                          ),
                        ],
                      ),
                      // const SizedBox(height: 24),
                      // Text(
                      //   loc.lastEatenDishes,
                      //   style: const TextStyle(
                      //     fontSize: 20,
                      //     fontWeight: FontWeight.bold,
                      //   ),
                      // ),
                      // const SizedBox(height: 16),
                      // MouseRegion(
                      //   onEnter: (_) {
                      //     setState(() {
                      //       _disableParentScroll = true;
                      //     });
                      //   },
                      //   onExit: (_) {
                      //     setState(() {
                      //       _disableParentScroll = false;
                      //     });
                      //   },
                      //   // child: SizedBox(
                      //   //   height: 150,
                      //   //   child: _buildDishList(),
                      //   // ),
                      // ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            )
          : loading(),
    );
  }
} 