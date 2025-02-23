import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';
import 'package:url_launcher/url_launcher.dart';

class GoogleCalendarService {
  late String clientId;
  late String clientSecret;
  late String redirectUri;
  final List<String> scopes = [calendar.CalendarApi.calendarScope];
  String? accessToken;

  GoogleCalendarService() {
    _loadCredentials();
  }

  /// Carrega credenciais do arquivo credentials.json
  void _loadCredentials() {
    try {
      final file = File('credentials/credentials.json');
      if (!file.existsSync()) {
        throw Exception('Arquivo credentials.json não encontrado!');
      }

      final credentials = jsonDecode(file.readAsStringSync());
      final web = credentials['web'];
      clientId = web['client_id'];
      clientSecret = web['client_secret'];
      redirectUri = web['redirect_uris'][0]; // Usa a primeira redirect_uri
      print('Credenciais carregadas com sucesso.');
    } catch (e) {
      print('Erro ao carregar o arquivo credentials.json: $e');
      rethrow;
    }
  }

  /// Verifica se um intervalo de tempo está disponível no Google Calendar
Future<bool> isTimeSlotAvailable(DateTime startTime, DateTime endTime) async {
  try {
    print('Verificando disponibilidade de horário...');

    // Obtemos todos os eventos do Google Calendar
    final events = await getCalendarEvents();

    // Percorremos os eventos para verificar se há sobreposição
    for (var event in events) {
      // Obtemos o horário de início e término do evento
      final eventStart = event.start?.dateTime ?? event.start?.date; // Pode ser dateTime ou apenas date
      final eventEnd = event.end?.dateTime ?? event.end?.date;

      if (eventStart != null && eventEnd != null) {
        // Verifica se há sobreposição entre os horários
        if (startTime.isBefore(eventEnd) && endTime.isAfter(eventStart)) {
          print('Conflito encontrado com o evento: ${event.summary}');
          return false; // Horário não está disponível
        }
      }
    }

    print('Horário disponível.');
    return true; // Horário está disponível
  } catch (e) {
    print('Erro ao verificar disponibilidade: $e');
    rethrow; // Propaga o erro para ser tratado pelo chamador
  }
}


  /// Inicia o processo de autenticação
  Future<void> authenticateAndSchedule(DateTime startTime, DateTime endTime, String title) async {
  try {
    final authUrl =
        'https://accounts.google.com/o/oauth2/v2/auth?response_type=code&client_id=$clientId&redirect_uri=$redirectUri&scope=${Uri.encodeComponent(scopes.join(" "))}&access_type=offline';

    print('Abra o seguinte link no navegador para autenticar: $authUrl');

    // Inicia um servidor HTTP local na porta 8080
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);

    server.listen((HttpRequest request) async {
      final code = request.uri.queryParameters['code']; // Captura o código
      if (code != null) {
        print('Código de autorização capturado: $code');
        await handleAuthorizationCode(code);

        // Após a autenticação bem-sucedida, tente agendar o evento
        final isAvailable = await isTimeSlotAvailable(startTime, endTime);
        if (isAvailable) {
          await createCalendarEvent(startTime, endTime, title);
          request.response
            ..statusCode = HttpStatus.ok
            ..write('Evento criado com sucesso! Você pode fechar esta aba.')
            ..close();
        } else {
          request.response
            ..statusCode = HttpStatus.ok
            ..write('Horário indisponível. Não foi possível agendar o evento.')
            ..close();
        }
      } else {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write('Erro ao capturar o código de autorização.')
          ..close();
      }
      server.close(); // Encerra o servidor após capturar o código
    });

    // Abre o navegador para o usuário se autenticar
    if (await canLaunch(authUrl)) {
      await launch(authUrl);
    } else {
      throw Exception('Não foi possível abrir o navegador para autenticação.');
    }
  } catch (e) {
    print('Erro ao iniciar autenticação: $e');
    rethrow;
  }
}


  /// Processa o código de autorização e obtém o token de acesso
  Future<void> handleAuthorizationCode(String code) async {
    try {
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': code,
          'client_id': clientId,
          'client_secret': clientSecret,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
        },
      );

      if (response.statusCode == 200) {
        final tokenData = jsonDecode(response.body);
        accessToken = tokenData['access_token'];
        print('Token de acesso obtido: $accessToken');
      } else {
        throw Exception('Erro ao obter token de acesso: ${response.body}');
      }
    } catch (e) {
      print('Erro ao processar autorização: $e');
      rethrow;
    }
  }

  /// Lista eventos do Google Calendar
  Future<List<calendar.Event>> getCalendarEvents() async {
    if (accessToken == null) {
      throw Exception('Usuário não autenticado. Chame authenticate() primeiro.');
    }

    final client = _authenticatedClient();
    final calendarApi = calendar.CalendarApi(client);

    try {
      final events = await calendarApi.events.list(
        "primary",
        timeMin: DateTime.now().toUtc(),
        timeMax: DateTime.now().add(Duration(days: 7)).toUtc(),
        singleEvents: true,
        orderBy: "startTime",
      );

      print('Eventos obtidos com sucesso.');
      return events.items ?? [];
    } catch (e) {
      print('Erro ao obter eventos: $e');
      rethrow;
    }
  }

  /// Cria um evento no Google Calendar
  Future<void> createCalendarEvent(
      DateTime startTime, DateTime endTime, String title) async {
    if (accessToken == null) {
      throw Exception('Usuário não autenticado. Chame authenticate() primeiro.');
    }

    final client = _authenticatedClient();
    final calendarApi = calendar.CalendarApi(client);

    try {
      final event = calendar.Event(
        summary: title,
        start: calendar.EventDateTime(
          dateTime: startTime.toUtc(),
          timeZone: "UTC",
        ),
        end: calendar.EventDateTime(
          dateTime: endTime.toUtc(),
          timeZone: "UTC",
        ),
      );

      await calendarApi.events.insert(event, "primary");
      print('Evento criado com sucesso!');
    } catch (e) {
      print('Erro ao criar evento: $e');
      rethrow;
    }
  }

  /// Cria um cliente HTTP autenticado
  http.Client _authenticatedClient() {
    return AuthenticatedClient(accessToken!);
  }
}

/// Cliente HTTP autenticado
class AuthenticatedClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _inner = http.Client();

  AuthenticatedClient(this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _inner.send(request);
  }
}
