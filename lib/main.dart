import 'package:flutter/material.dart';
import 'package:targeted_popups/targeted_popups.dart';
//import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Targeted Popup Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Targeted Popup Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  TargetedPopupManager manager = TargetedPopupManager(
    onSeen: (key) {
      print(key + ' has been seen');
    },
  ).addPage('home', ['0', '1']);

  @override
  void initState() {
    // SharedPreferences.getInstance().then((pref) {});
    manager.discover('home');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TargetedPopup(
                notifier: manager.notifier('home', '0'),
                content: Text('Lorem ipsum dolor sit amet.'),
                backgroundColor: Colors.lightGreenAccent,
                target: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.deepPurple),
                  ),
                  child: Text('Hello'),
                ),
              ),
              TargetedPopup(
                notifier: manager.notifier('home', '1'),
                content: Text('Lorem ipsum dolor sit amet.'),
                backgroundColor: Colors.lightGreenAccent,
                target: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.deepPurple),
                  ),
                  child: Text('Hello Again'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    manager.dispose();
    super.dispose();
  }
}
