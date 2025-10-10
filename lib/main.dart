import 'dart:io' as io;

import 'package:cupertino_http/cupertino_http.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const NetworkTrafficApp());
}

class NetworkTrafficApp extends StatelessWidget {
  const NetworkTrafficApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Traffic app',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const NetworkTrafficPage(title: 'Network Traffic'),
    );
  }
}

class NetworkTrafficPage extends StatefulWidget {
  const NetworkTrafficPage({super.key, required this.title});

  final String title;

  @override
  State<NetworkTrafficPage> createState() => _NetworkTrafficPageState();
}

class _NetworkTrafficPageState extends State<NetworkTrafficPage> {
  final _log = StringBuffer();

  final _logScrollController = ScrollController();

  bool _needsScroll = false;

  void _scrollToEnd() async {
    _logScrollController.animateTo(
      _logScrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: 100),
      curve: Curves.decelerate,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Initialize the global HTTP server.
    _server;
    if (_needsScroll) {
      _scrollToEnd();
      _needsScroll = false;
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Center(child: RequestTable(logWriteln: _logWriteln)),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              controller: _logScrollController,
              child: Text(_log.toString()),
            ),
          ),
        ],
      ),
    );
  }

  void _logWriteln(String text) {
    setState(() {
      _log.writeln(text);
      _needsScroll = true;
    });
  }
}

class RequestTable extends StatefulWidget {
  final void Function(String) _logWriteln;

  RequestTable({required void Function(String) logWriteln, super.key})
    : _logWriteln = logWriteln;

  @override
  State<RequestTable> createState() => _RequestTableState();
}

class _RequestTableState extends State<RequestTable> {
  List<_RequestSettings> settingsList = [
    _RequestSettings(
      type: _RequestType.httpGet,
      action: _client.get,
      requestHasBody: null,
      requestCanHaveBody: false,
    ),
    _RequestSettings(type: _RequestType.httpPost, action: _client.post),
    _RequestSettings(type: _RequestType.httpPut, action: _client.put),
    _RequestSettings(
      type: _RequestType.httpDelete,
      action: _client.delete,
      requestHasBody: null,
      requestCanHaveBody: false,
    ),
    _RequestSettings(
      type: _RequestType.packageHttpGet,
      action: _client.packageHttpGet,
    ),
    _RequestSettings(
      type: _RequestType.packageHttpPost,
      action: _client.packageHttpPost,
    ),
    _RequestSettings(
      type: _RequestType.packageHttpPostStreamed,
      action: _client.packageHttpPostStreamed,
      requestHasBody: null,
      requestCanHaveBody: true,
    ),
    if (io.Platform.isIOS || io.Platform.isMacOS)
      _RequestSettings(
        type: _RequestType.cupertinoHttpPost,
        action: _client.cupertinoHttpPost,
      ),
    _RequestSettings(type: _RequestType.dioGet, action: _client.dioGet),
    _RequestSettings(type: _RequestType.dioPost, action: _client.dioPost),
  ];

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: {
        0: FlexColumnWidth(3), // Type
        1: FlexColumnWidth(), // Request body?
        2: FlexColumnWidth(), // Response body?
        3: FlexColumnWidth(), // Completes?
        4: FlexColumnWidth(), // Repeats?
        5: FlexColumnWidth(), // Go
      },
      children: [
        TableRow(
          children: [
            Text('Type'),
            Text('Request body?'),
            Text('Response body?'),
            // TODO: status code?
            // TODO: streaming response?
            Text('Completes?'),
            Text('Repeats?'),
            Text(''),
          ],
        ),
        for (var settings in settingsList)
          TableRow(
            children: [
              Text(settings.type.text),
              Checky(
                isChecked:
                    settings.requestHasBody ?? settings.requestCanHaveBody,
                onChanged: settings.requestHasBody == null
                    ? null
                    : (bool? value) {
                        setState(() {
                          settings.requestHasBody = value ?? true;
                        });
                      },
              ),
              Checky(
                isChecked: settings.responseHasBody,
                onChanged: (bool? value) {
                  setState(() {
                    settings.responseHasBody = value ?? true;
                  });
                },
              ),
              Checky(
                isChecked: settings.shouldComplete,
                onChanged: (bool? value) {
                  setState(() {
                    settings.shouldComplete = value ?? false;
                  });
                },
              ),
              Checky(isChecked: settings.shouldRepeat, onChanged: null),
              TextButton(
                onPressed: () => settings.action(
                  logWriteln: widget._logWriteln,
                  requestHasBody: settings.requestHasBody ?? false,
                  responseHasBody: settings.responseHasBody,
                  // TODO: wire this up to a text field.
                  responseCode: 200,
                ),
                child: Text('Go'),
              ),
            ],
          ),
      ],
    );
  }
}

class _RequestSettings {
  final _RequestType type;
  final void Function({
    required Logger logWriteln,
    required bool requestHasBody,
    required bool responseHasBody,
    required int responseCode,
    bool shouldComplete,
  })
  action;

  /// `null` means disabled.
  bool? requestHasBody;
  bool requestCanHaveBody;
  bool responseHasBody = true;
  bool shouldComplete = true;
  bool shouldRepeat = false;

  _RequestSettings({
    required this.type,
    required this.action,
    this.requestHasBody = false,
    this.requestCanHaveBody = true,
  });
}

enum _RequestType {
  httpGet('HttpClient GET'),
  httpPost('HttpClient POST'),
  httpPut('HttpClient PUT'),
  httpDelete('HttpClient DELETE'),
  packageHttpGet('package:http (IOClient) GET'),
  packageHttpPost('package:http (IOClient) POST'),
  packageHttpPostStreamed('package:http (IOClient) POST (streamed)'),
  cupertinoHttpPost('package:cupertino_http POST'),
  dioGet('Dio GET'),
  dioPost('Dio POST');
  // TODO: WebSocket
  // TODO: cronet_http - https://pub.dev/packages/cronet_http
  // TODO: ok_http - https://pub.dev/packages/ok_http

  final String text;

  const _RequestType(this.text);
}

class Checky extends StatelessWidget {
  final bool isChecked;

  final void Function(bool?)? _onChanged;

  Checky({
    required this.isChecked,
    required void Function(bool?)? onChanged,
    super.key,
  }) : _onChanged = onChanged;

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: isChecked,
      onChanged: _onChanged == null
          ? null
          : (bool? value) {
              _onChanged(value);
            },
    );
  }
}

typedef Logger = void Function(String);

class _HttpClient {
  final io.HttpClient client = io.HttpClient();

  void get({
    required Logger logWriteln,
    required bool requestHasBody,
    required bool responseHasBody,
    required int responseCode,
    bool shouldComplete = true,
  }) async {
    var uri = _computeUri(
      responseHasBody: responseHasBody,
      shouldComplete: shouldComplete,
      responseCode: responseCode,
    );
    logWriteln('Sending GET to $uri...');
    final request = await client.getUrl(uri);
    logWriteln('Sent GET.');
    // No body.
    final response = await request.done;
    logWriteln('Received GET response: $response');
  }

  void post({
    required Logger logWriteln,
    required bool requestHasBody,
    required bool responseHasBody,
    required int responseCode,
    bool shouldComplete = true,
  }) async {
    var uri = _computeUri(
      responseHasBody: responseHasBody,
      shouldComplete: shouldComplete,
      responseCode: responseCode,
    );
    logWriteln('Sending POST to $uri...');
    final request = await client.postUrl(uri);
    logWriteln('Sent POST.');
    if (requestHasBody) {
      request.write('Request Body');
    }
    final response = await request.done;
    logWriteln('Received POST response: $response');
  }

  void put({
    required Logger logWriteln,
    required bool requestHasBody,
    required bool responseHasBody,
    required int responseCode,
    bool shouldComplete = true,
  }) async {
    var uri = _computeUri(
      responseHasBody: responseHasBody,
      shouldComplete: shouldComplete,
      responseCode: responseCode,
    );
    logWriteln('Sending PUT to $uri...');
    final request = await client.putUrl(uri);
    logWriteln('Sent PUT.');
    if (requestHasBody) {
      request.write('Request Body');
    }
    final response = await request.done;
    logWriteln('Received PUT response: $response');
  }

  void delete({
    required Logger logWriteln,
    required bool requestHasBody,
    required bool responseHasBody,
    required int responseCode,
    bool shouldComplete = true,
  }) async {
    var uri = _computeUri(
      responseHasBody: responseHasBody,
      shouldComplete: shouldComplete,
      responseCode: responseCode,
    );
    logWriteln('Sending DELETE to $uri...');
    final request = await client.deleteUrl(uri);
    logWriteln('Sent DELETE.');
    if (requestHasBody) {
      request.write('Request Body');
    }
    final response = await request.done;
    logWriteln('Received DELETE response: $response');
  }

  void packageHttpGet({
    required Logger logWriteln,
    // Unused.
    required bool requestHasBody,
    required bool responseHasBody,
    required int responseCode,
    bool shouldComplete = true,
  }) async {
    var uri = _computeUri(
      responseHasBody: responseHasBody,
      shouldComplete: shouldComplete,
      responseCode: responseCode,
    );
    logWriteln('Sending package:http GET to $uri...');
    var response = await http.get(uri);
    logWriteln('Received package:http GET response: ${response.body}');
  }

  void packageHttpPost({
    required Logger logWriteln,
    required bool requestHasBody,
    required bool responseHasBody,
    required int responseCode,
    bool shouldComplete = true,
  }) async {
    var uri = _computeUri(
      responseHasBody: responseHasBody,
      shouldComplete: shouldComplete,
      responseCode: responseCode,
    );
    logWriteln('Sending package:http POST...');
    var response = await http.post(
      uri,
      body: requestHasBody ? {'name': 'doodle', 'color': 'blue'} : null,
    );
    logWriteln('Received package:http POST response: ${response.body}');
  }

  void packageHttpPostStreamed({
    required Logger logWriteln,
    // Unused.
    required bool requestHasBody,
    required bool responseHasBody,
    required int responseCode,
    bool shouldComplete = true,
  }) async {
    var uri = _computeUri(
      responseHasBody: responseHasBody,
      shouldComplete: shouldComplete,
      responseCode: responseCode,
    );
    logWriteln('Sending streamed package:http POST to $uri...');
    var request = http.StreamedRequest('POST', uri)
      ..contentLength = 20
      ..sink.add([11, 12, 13, 14, 15, 16, 17, 18, 19, 20])
      ..sink.add([21, 22, 23, 24, 25, 26, 27, 28, 29, 30]);
    request.sink.close();
    var response = await request.send();

    logWriteln('Received package:http POST response: $response');
  }

  void cupertinoHttpPost({
    required Logger logWriteln,
    required bool requestHasBody,
    required bool responseHasBody,
    required int responseCode,
    bool shouldComplete = true,
  }) async {
    var uri = _computeUri(
      responseHasBody: responseHasBody,
      shouldComplete: shouldComplete,
      responseCode: responseCode,
    );
    logWriteln('Sending package:cupertino_http POST to $uri...');

    final config = URLSessionConfiguration.ephemeralSessionConfiguration()
      ..cache = URLCache.withCapacity(memoryCapacity: 2 * 1024 * 1024)
      ..httpAdditionalHeaders = {'User-Agent': 'Book Agent'};
    final httpClient = CupertinoClient.fromSessionConfiguration(config);
    final response = await httpClient.get(uri);

    logWriteln(
      'Received package:cupertino_http POST response: ${response.body}',
    );
  }

  void dioGet({
    required Logger logWriteln,
    required bool requestHasBody,
    required bool responseHasBody,
    required int responseCode,
    bool shouldComplete = true,
  }) async {
    var uri = _computeUri(
      responseHasBody: responseHasBody,
      shouldComplete: shouldComplete,
      responseCode: responseCode,
    );
    logWriteln('Sending Dio GET to $uri...');
    // No body.
    final response = await _dio.getUri(uri);
    logWriteln('Recived Dio GET response; headers: ${response.headers}');
  }

  void dioPost({
    required Logger logWriteln,
    required bool requestHasBody,
    required bool responseHasBody,
    required int responseCode,
    bool shouldComplete = true,
  }) async {
    var uri = _computeUri(
      responseHasBody: responseHasBody,
      shouldComplete: shouldComplete,
      responseCode: responseCode,
    );
    logWriteln('Sending Dio POST to $uri...');
    final response = await _dio.postUri(
      uri,
      data: requestHasBody ? {'a': 'b', 'c': 'd'} : null,
    );
    logWriteln('Received Dio POST response: $response');
  }

  Uri _computeUri({
    required bool responseHasBody,
    required bool shouldComplete,
    required int responseCode,
  }) => Uri.http(
    '127.0.0.1:8888',
    [
      '/',
      if (responseHasBody) 'responseHasBody/',
      if (shouldComplete) 'complete/',
    ].join(),
    {'responseCode': '$responseCode'},
  );
}

final _client = _HttpClient();

class _HttpServer {
  final io.HttpServer server;

  _HttpServer(this.server);

  static Future<_HttpServer> create() async {
    print('Starting server on port 8888...');
    final io.HttpServer ioServer;
    try {
      ioServer = await io.HttpServer.bind(
        io.InternetAddress.loopbackIPv4,
        8888,
      );
    } catch (e, st) {
      print('Could not bind: $e\n$st');
      rethrow;
    }
    ioServer.listen((request) {
      final path = request.uri.path;
      print('Received request at $path');
      final queryParameters = request.uri.queryParameters;
      final responseCode =
          int.tryParse(queryParameters['responseCode'] ?? '200') ?? 200;
      request.response.statusCode = responseCode;
      if (path.contains('responseHasBody/')) {
        request.response.write('response body');
      }
      if (path.contains('complete/')) {
        print('Closing response...');
        request.response.close();
        print('Closed response.');
      }
    });
    print('Started server at ${ioServer.address}.');
    return _HttpServer(ioServer);
  }

  int get port => server.port;
}

final Future<_HttpServer> _server = _HttpServer.create();

final _dio = Dio();
