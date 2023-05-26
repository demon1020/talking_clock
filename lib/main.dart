import 'dart:async';
import 'dart:isolate';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_analog_clock/flutter_analog_clock.dart';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';

void main() async {
  await GetStorage.init();
  runApp(TalkingClockApp());
}

class TalkingClockApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Talking Clock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      translations: MyTranslations(),
      locale: Get.deviceLocale,
      home: TalkingClockScreen(),
    );
  }
}

class MyTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': {
          'title': 'Talking Clock',
          'listen': 'Listen',
        },
        'es_ES': {
          'title': 'Reloj Parlante',
          'listen': 'Escuchar',
        },
        'hi_IN': {
          'title': 'बात करने वाली घड़ी',
          'listen': 'समय सुनो',
        },
        // Add more language translations as needed
      };
}

class TalkingClockScreen extends StatefulWidget {
  @override
  _TalkingClockScreenState createState() => _TalkingClockScreenState();
}

class _TalkingClockScreenState extends State<TalkingClockScreen> {
  late FlutterTts flutterTts;
  String currentTime = '';
  late FlutterIsolate clockIsolate;
  late Locale selectedLocale = supportedLocales.last;
  double pitch = 1.0;
  double speechRate = 0.4;
  static int repeatPeriod = 60;
  static RxBool isInitialised = false.obs;
  GetStorage box = GetStorage();
  static DateTime dateTime = DateTime.now();

  List<Locale> supportedLocales = [
    Locale('en', 'US'),
    Locale('es', 'ES'),
    Locale('hi', 'IN'),
    // Add more supported locales as needed
  ];

  Future<List<Locale>> getData(filter) async {
    supportedLocales
        .where((element) => element.languageCode.contains(filter))
        .toList();
    return supportedLocales;
  }

  @override
  void initState() {
    init();
    super.initState();
  }

  init() async {
    flutterTts = FlutterTts();
    dynamic savedLocale = box.read("locale");
    if (savedLocale != null && savedLocale.isNotEmpty) {
      selectedLocale =
          Locale(savedLocale.substring(0, 2), savedLocale.substring(3, 5));
    }
    await initializeTts();
    startClockIsolate();
  }

  Future<void> initializeTts() async {
    await flutterTts.setLanguage(selectedLocale.languageCode);
    await flutterTts.setPitch(pitch);
    await flutterTts.setSpeechRate(speechRate);
    await flutterTts.awaitSpeakCompletion(true);
    await flutterTts.awaitSynthCompletion(true);
    changeLanguage(selectedLocale);
  }

  void startClockIsolate() async {
    final receivePort = ReceivePort();
    clockIsolate =
        await FlutterIsolate.spawn(runClockIsolate, receivePort.sendPort);
    receivePort.listen((dynamic message) {
      setState(() {
        currentTime = message as String;
        isInitialised = RxBool(true);
      });
      //Enable to tell automatic in specified period
      // speakTime(currentTime);
    });
  }

  static void runClockIsolate(SendPort sendPort) {
    Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      final currentTime = DateFormat.jm().format(dateTime);
      sendPort.send(currentTime);
    });
  }

  Future<void> speakTime(String time) async {
    await flutterTts.speak(time);
  }

  void listenToTime() {
    speakTime(currentTime);
  }

  void changeLanguage(Locale? locale) {
    if (locale != null) {
      Get.updateLocale(locale);
    }
  }

  @override
  void dispose() {
    clockIsolate.kill();
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('title'.tr),
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              DropdownSearch<Locale>(
                // autoValidateMode: AutovalidateMode.always,
                selectedItem: selectedLocale,
                popupProps: PopupProps.menu(
                  showSearchBox: true,
                ),
                // dropdownSearchDecoration: InputDecoration(labelText: "Name"),
                asyncItems: (String filter) => getData(filter),
                itemAsString: (Locale locale) => locale.languageCode,
                onChanged: (Locale? locale) async {
                  selectedLocale = locale!;
                  await initializeTts();
                  box.write("locale", selectedLocale.toString());
                },
              )
            ],
          ),
        ),
      ),
      body: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnalogClock(
              dateTime: dateTime,
              isKeepTime: true,
              child: const Align(
                alignment: FractionalOffset(0.5, 0.75),
                child: Text('Prabhavati'),
              ),
            ),
            InkWell(
              splashColor: Colors.orangeAccent,
              highlightColor: Colors.orangeAccent,
              borderRadius: BorderRadius.circular(100),
              onTap: listenToTime,
              child: Container(
                height: 100,
                width: 100,
                padding: EdgeInsets.all(10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: currentTime.isEmpty ? Colors.orangeAccent : Colors.blue,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'listen'.tr,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
