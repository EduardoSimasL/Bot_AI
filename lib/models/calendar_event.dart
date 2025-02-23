class CalendarEvent {
  final String title;
  final DateTime startTime;
  final DateTime endTime;

  CalendarEvent({
    required this.title,
    required this.startTime,
    required this.endTime,
  });

  @override
  String toString() =>
      'Evento: $title, Início: $startTime, Fim: $endTime';
}
