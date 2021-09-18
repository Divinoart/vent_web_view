import 'dart:io';

import 'package:connectivity/connectivity.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lottie/lottie.dart';
import 'package:vent_app/in_app_web_view.dart';



Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();
  print('Handling a background message ${message.messageId}');
}

/// Create a [AndroidNotificationChannel] for heads up notifications
AndroidNotificationChannel channel = AndroidNotificationChannel("id", 'name', 'description');

/// Initialize the [FlutterLocalNotificationsPlugin] package.
FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void _enablePlatformOverrideForDesktop() {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  _enablePlatformOverrideForDesktop();

  // Set the background messaging handler early on, as a named top-level function
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  if (!kIsWeb) {
    channel = const AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      'This channel is used for important notifications.', // description
      importance: Importance.high,
    );

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    /// Create an Android Notification Channel.
    ///
    /// We use this channel in the `AndroidManifest.xml` file to override the
    /// default FCM channel to enable heads up notifications.
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    /// Update the iOS foreground notification presentation options to allow
    /// heads up notifications.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DTH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: CheckConnectivity(),
      // home: SplashScreen(),
    );
  }
}

// Crude counter to make messages unique
int _messageCount = 0;

/// The API endpoint here accepts a raw FCM payload for demonstration purposes.
String constructFCMPayload(String token) {
  _messageCount++;
  return jsonEncode({
    'token': token,
    'data': {
      'via': 'FlutterFire Cloud Messaging!!!',
      'count': _messageCount.toString(),
    },
    'notification': {
      'title': 'Hello FlutterFire!',
      'body': 'This notification (#$_messageCount) was created via FCM!',
    },
  });
}



class CheckConnectivity extends StatefulWidget {
  @override
  _CheckConnectivityState createState() => _CheckConnectivityState();
}

class _CheckConnectivityState extends State<CheckConnectivity> {
  String _connectionStatus = 'Unknown';
  String _networkStatus = 'connected';
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  @override
  initState() {
    super.initState();
    initConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> initConnectivity() async {
    ConnectivityResult result = ConnectivityResult.none;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      result = await _connectivity.checkConnectivity();
      print(_connectionStatus);
    } on PlatformException catch (e) {
      print(e.toString());
    }
    if (!mounted) {
      return Future.value(null);
    }
    return _updateConnectionStatus(result);
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    switch (result) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.mobile:
//      case ConnectivityResult.none:
      //todo: i added this to ensure there is internet connection
        try {
          final result = await InternetAddress.lookup('google.com');
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            print('connected');
            print(result);
            setState(() {
              _networkStatus = 'connected';
              // _showMsg(_networkStatus.toString());
              _network();
            });
          }
        } on SocketException catch (_) {
          print('not connected');
          setState(() {
            _networkStatus = 'Please check your network connection';
            _showMsg(_networkStatus.toString());
            _network();
          });
        }
        //todo: end here
        setState(() => _connectionStatus = result.toString());
        break;
      case ConnectivityResult.none:
        setState(() {
          _networkStatus = 'Please check your network connection';
          _network();
          _showMsg(_networkStatus.toString());
          _connectionStatus = result.toString();
        });

        break;
      default:
        setState(() {
          _connectionStatus = 'Failed to get connectivity.';
          _networkStatus = 'Please check your network connection';
          _network();
        });
        break;
    }
  }

  void _network() {
    if (_networkStatus == 'Please check your network connection') {
      _showMsg(_networkStatus.toString());
    } else {
      print(_networkStatus);
    }
  }

  _showMsg(msg, [String? action, void Function()? function]) {
    final snackBar = SnackBar(
      backgroundColor: Colors.red,
      content: Text(msg),
      action: SnackBarAction(
          label: action ?? 'Close',
          textColor: Colors.white,
          onPressed: function?? (){}
      ),
    );
    FocusScope.of(context).requestFocus(new FocusNode());
    _scaffoldKey.currentState?.removeCurrentSnackBar();
    _scaffoldKey.currentState?.showSnackBar(snackBar);
  }

// Be sure to cancel subscription after you are done
  @override
  dispose() {
    super.dispose();
    _connectivitySubscription.cancel();
  }
  @override
  Widget build(BuildContext context) {
    Widget child;
    if(_networkStatus == 'connected'){
      // child = HomePage();
      child = InAppWebViewExampleScreen();

    }else {
      child = Container(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Lottie.asset('assets/images/network.json'),
                ),
                Text('Ooops!'),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text('Network Disconnected',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,),
                ),
                SizedBox(height: 40,),
                InkWell(
                  onTap: (){
                    initConnectivity();
                  },
                  borderRadius: BorderRadius.circular(15),
                  splashColor: Color(0xff4caf50).withOpacity(0.1),
                  highlightColor: Color(0xff4caf50).withOpacity(0.1),
                  child: Container(
                      decoration: BoxDecoration(
                          border: Border.all(color: Color(0xff4caf50).withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(15),
                          color: Color(0xff4caf50),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.grey,
                                blurRadius: 1,
                                offset: Offset(0, 0)),
                          ]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical:12.0, horizontal:30),
                        child: Text('Refresh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),),
                      )
                  ),
                )
              ],
            ),
          )
      );
    }
    return Scaffold(
      key: _scaffoldKey,
      body: child,
    );
  }
}