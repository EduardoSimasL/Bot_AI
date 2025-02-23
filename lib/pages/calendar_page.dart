import 'package:flutter/material.dart';
import '../services/google_calendar_service.dart';

class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final GoogleCalendarService _service = GoogleCalendarService();
  DateTime? _selectedDate; // Data selecionada
  TimeOfDay? _selectedTime; // Hora selecionada
  int _durationInMinutes = 60; // Duração padrão em minutos
  final TextEditingController _titleController = TextEditingController(); // Título do evento

  /// Abre o seletor de data
  Future<void> _selectDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)), // Até 1 ano no futuro
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  /// Abre o seletor de horário
  Future<void> _selectTime(BuildContext context) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime != null) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  /// Autentica e agenda a reunião com os dados fornecidos
  Future<void> _authenticateAndScheduleMeeting() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, selecione a data e o horário.')),
      );
      return;
    }

    final startDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    final endDateTime = startDateTime.add(Duration(minutes: _durationInMinutes));

    try {
      await _service.authenticateAndSchedule(startDateTime, endDateTime, _titleController.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Agendar Reunião'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Título do Evento',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () => _selectDate(context),
                  child: Text(_selectedDate == null
                      ? 'Escolher Data'
                      : 'Data: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                ),
                ElevatedButton(
                  onPressed: () => _selectTime(context),
                  child: Text(_selectedTime == null
                      ? 'Escolher Horário'
                      : 'Hora: ${_selectedTime!.format(context)}'),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Duração (min):'),
                DropdownButton<int>(
                  value: _durationInMinutes,
                  items: [30, 60, 90, 120].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value min'),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _durationInMinutes = newValue!;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _authenticateAndScheduleMeeting,
              child: Text('Autenticar e Agendar'),
            ),
          ],
        ),
      ),
    );
  }
}
