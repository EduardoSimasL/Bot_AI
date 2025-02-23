import 'package:flutter/material.dart';
import 'pages/calendar_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agendamento Automático',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: CalendarPage(),
    );
  }
}
