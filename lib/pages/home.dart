import 'package:flutter/material.dart';
import 'login.dart';
import '../api/user.dart';
import '../widgets/waterWidget.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          logoutButton(context),
        ],
      ),
      body: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            child: buildBody(context),
          )),
    );
  }
}

// Komentarz
Container buildBody(context) {
  return Container(
      child: Column(children: [
    // const SizedBox(height: 20),
    searchBar(context),
    // const SizedBox(height: 20),
    mainWidgets(context),
  ]));
}

Container mainWidgets(context) {
  return Container(
    child: Column(children: [
      Wrap(
        // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        spacing: 10,
        runSpacing: 20,
        children: [
          waterWidget(context),
          frigdeWidget(context),
        ],
      ),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          calendarWidget(context),
        ],
      )
    ]),
  );
}



Container frigdeWidget(context) {
  return Container(
    margin: const EdgeInsets.fromLTRB(5, 0, 5, 0),
    width: 160,
    height: 160,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: Color(0xff1D1617).withOpacity(0.05),
          blurRadius: 40,
          spreadRadius: 0.0,
        )
      ],
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey, width: 1),
    ),
    child: Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Icon(
              Icons.kitchen,
              size: 30,
              color: Colors.grey,
            ),
            Text('Fridge',
                style: TextStyle(
                    fontSize: 25,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Your fridge\n  is empty',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                )),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
              ),
              onPressed: () {
                print('Fridge');
              },
              child: const Text('Add products',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        )
      ],
    ),
  );
}

Container calendarWidget(context) {
  return Container(
    width: MediaQuery.of(context).size.width - 20,
    margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: Color(0xff1D1617).withOpacity(0.05),
          blurRadius: 40,
          spreadRadius: 0.0,
        )
      ],
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.green, width: 1),
    ),
    child: Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(
              Icons.calendar_month,
              size: 30,
              color: Colors.green,
            ),
            const SizedBox(width: 10),
            Text('Calendar',
                style: TextStyle(
                    fontSize: 25,
                    color: Colors.green,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        // Chwilowo jest const potem zmienić jak będzie działało zapisywanie wody
        const Wrap(
          // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          spacing: 20,
          children: [
            Column(
              children: [
                Text('Today',
                    style: TextStyle(
                        fontSize: 20,
                        color: Colors.green,
                        fontWeight: FontWeight.bold)),
                Text('Sniadanie: Gofry',
                    style: TextStyle(fontSize: 15, color: Colors.black)),
                Text('2 Sniadanie: Gofry',
                    style: TextStyle(fontSize: 15, color: Colors.black)),
                Text('Obiad: Gofry',
                    style: TextStyle(fontSize: 15, color: Colors.black)),
                Text('Kolacja: Gofry',
                    style: TextStyle(fontSize: 15, color: Colors.black)),
              ],
            ),
            Column(
              children: [
                Text('Tomorrow',
                    style: TextStyle(
                        fontSize: 20,
                        color: Colors.green,
                        fontWeight: FontWeight.bold)),
                Text('Sniadanie: Gofry',
                    style: TextStyle(fontSize: 15, color: Colors.black)),
                Text('2 Sniadanie: Gofry',
                    style: TextStyle(fontSize: 15, color: Colors.black)),
                Text('Obiad: Gofry',
                    style: TextStyle(fontSize: 15, color: Colors.black)),
                Text('Kolacja: Gofry',
                    style: TextStyle(fontSize: 15, color: Colors.black)),
              ],
            )
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              onPressed: () {
                print('Edit calendar');
              },
              child: const Text('Edit calendar',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        )
      ],
    ),
  );
}

Column searchBar(context) {
  return Column(
    children: [
      Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color(0xff1D1617).withOpacity(0.05),
                blurRadius: 40,
                spreadRadius: 0.0,
              ),
            ],
            border: Border.all(
                color: Color(0xff1D1617).withOpacity(0.05), width: 1),
            borderRadius: const BorderRadius.all(Radius.circular(10.0)),
          ),
          // margin: const EdgeInsets.all(20),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: const TextField(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'Wyszukaj...',
              hintStyle: TextStyle(
                color: Colors.black,
              ),
              prefixIcon: Icon(Icons.search, color: Colors.black),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10.0)),
                borderSide: BorderSide.none,
              ),
              // suffixIcon: IconButton(
              //   icon: const Icon(Icons.mic),
              //   color: Colors.black,
              //   onPressed: () {
              //     print('Voice search');
              //   },
              // )
            ),
          ))
    ],
  );
}

IconButton logoutButton(context) {
  return IconButton(
    icon: const Icon(Icons.logout),
    onPressed: () async {
      await storage.delete(key: 'accessToken');
      await storage.delete(key: 'refreshToken');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
    },
  );
}
