import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/slot_assignment.dart';
import 'eip191_verifier.dart';
import 'core.dart';

/// A single log entry for the API request log
class ApiLogEntry {
  final DateTime timestamp;
  final String method;
  final String path;
  final String? clientAddress;
  final int statusCode;
  final String? error;

  ApiLogEntry({
    required this.timestamp,
    required this.method,
    required this.path,
    this.clientAddress,
    required this.statusCode,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'method': method,
        'path': path,
        'clientAddress': clientAddress,
        'statusCode': statusCode,
        'error': error,
      };
}

/// Result from a handler — carries both data and an appropriate HTTP status code
class _HandlerResult {
  final int statusCode;
  final Map<String, dynamic> body;

  _HandlerResult(this.statusCode, this.body);

  _HandlerResult.ok(this.body) : statusCode = 200;
  _HandlerResult.notFound(String message)
      : statusCode = 404,
        body = {'error': message};
  _HandlerResult.conflict(String message)
      : statusCode = 409,
        body = {'error': message};
  _HandlerResult.badRequest(String message)
      : statusCode = 400,
        body = {'error': message};
}

/// Extension managing the HTTP API server
class ApiExtension {
  final Core _core;

  ApiExtension(this._core);

  HttpServer? _server;
  Timer? _cleanupTimer;

  // Anti-replay: signature -> time used
  final Map<String, DateTime> _usedSignatures = {};

  // Request log ring buffer (max 100 entries)
  final List<ApiLogEntry> _requestLog = [];
  static const int _maxLogEntries = 100;

  bool get isRunning => _server != null;
  int? get boundPort => _server?.port;
  List<ApiLogEntry> get requestLog => List.unmodifiable(_requestLog);

  /// All available endpoint definitions
  static const List<ApiEndpoint> endpoints = [
    ApiEndpoint('GET', '/api/state', 'get_state'),
    ApiEndpoint('GET', '/api/tasks', 'get_tasks'),
    ApiEndpoint('GET', '/api/tasks/:id', 'get_task'),
    ApiEndpoint('POST', '/api/tasks/:id/run', 'run_task'),
    ApiEndpoint('POST', '/api/tasks/:id/stop', 'stop_task'),
    ApiEndpoint('POST', '/api/tasks/:id/kill', 'kill_task'),
    ApiEndpoint('POST', '/api/tasks/:id/input', 'input_task'),
    ApiEndpoint('GET', '/api/templates', 'get_templates'),
    ApiEndpoint('POST', '/api/templates/:id/launch', 'launch_template'),
    ApiEndpoint('GET', '/api/layout', 'get_layout'),
    ApiEndpoint('POST', '/api/layout/assign', 'assign_layout'),
    ApiEndpoint('GET', '/api/history', 'get_history'),
    ApiEndpoint('GET', '/api/resources/:taskId', 'get_resources'),
  ];

  /// Start the HTTP server
  Future<void> start() async {
    if (_server != null) return;

    final port = _core.settings.current.apiPort;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      debugPrint('ApiExtension: Server started on 127.0.0.1:$port');

      _server!.listen(_handleRequest);

      // Cleanup timer for anti-replay map
      _cleanupTimer = Timer.periodic(const Duration(seconds: 60), (_) {
        _cleanupUsedSignatures();
      });

      _core.notify();
    } catch (e) {
      debugPrint('ApiExtension: Failed to start server: $e');
      _server = null;
    }
  }

  /// Stop the HTTP server
  Future<void> stop() async {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    await _server?.close();
    _server = null;
    _usedSignatures.clear();
    debugPrint('ApiExtension: Server stopped');
    _core.notify();
  }

  /// Check if a specific endpoint is enabled
  bool _isEndpointEnabled(String action) {
    final toggles = _core.settings.current.apiEndpointToggles;
    // Default to enabled unless explicitly disabled
    return toggles[action] ?? true;
  }

  /// Handle incoming HTTP request
  Future<void> _handleRequest(HttpRequest request) async {
    final method = request.method;
    final path = request.uri.path;
    String? clientAddress;

    try {
      // CORS headers for local dev
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      request.response.headers.set('Access-Control-Allow-Headers', 'Content-Type, X-Signed-Request');
      request.response.headers.set('Content-Type', 'application/json');

      if (method == 'OPTIONS') {
        request.response.statusCode = 200;
        await request.response.close();
        return;
      }

      // Match route
      final match = _matchRoute(method, path);
      if (match == null) {
        await _respond(request, 404, {'error': 'Not found'});
        _log(method, path, null, 404, 'Not found');
        return;
      }

      final endpoint = match.endpoint;

      // Check if endpoint is enabled
      if (!_isEndpointEnabled(endpoint.action)) {
        await _respond(request, 403, {'error': 'Endpoint disabled'});
        _log(method, path, null, 403, 'Endpoint disabled');
        return;
      }

      // Parse request data — needed for both auth and handler dispatch
      Map<String, dynamic> requestData = {};
      final allowedAddresses = _core.settings.current.apiAllowedAddresses;

      if (allowedAddresses.isNotEmpty) {
        // Auth enabled: parse signed request, validate, extract data
        final authResult = await _authenticate(request, endpoint.action, allowedAddresses);
        if (authResult == null) return; // Response already sent
        clientAddress = authResult.address;
        requestData = authResult.data;
      } else if (method == 'POST') {
        // No auth but POST: read body as plain JSON to get request data
        final bodyStr = await utf8.decoder.bind(request).join();
        if (bodyStr.isNotEmpty) {
          try {
            final parsed = jsonDecode(bodyStr) as Map<String, dynamic>;
            // Support both raw body and signed-request-shaped body
            requestData = (parsed['data'] as Map<String, dynamic>?) ?? parsed;
          } catch (_) {
            await _respond(request, 400, {'error': 'Invalid JSON body'});
            _log(method, path, null, 400, 'Invalid JSON body');
            return;
          }
        }
      }

      // Route to handler
      final result = await _dispatch(endpoint, match.params, requestData);
      await _respond(request, result.statusCode, result.body);
      _log(method, path, clientAddress, result.statusCode,
          result.statusCode >= 400 ? result.body['error'] as String? : null);
    } catch (e) {
      await _respond(request, 500, {'error': 'Internal server error'});
      _log(method, path, clientAddress, 500, e.toString());
    }
  }

  /// Authenticate the request using EIP-191 signature
  /// Returns the recovered address and request data on success,
  /// or null (and sends error response) on failure
  Future<_AuthResult?> _authenticate(
    HttpRequest request,
    String action,
    List<String> allowedAddresses,
  ) async {
    try {
      SignedRequest signedReq;

      if (request.method == 'GET') {
        // GET: auth payload in X-Signed-Request header
        final headerValue = request.headers.value('X-Signed-Request');
        if (headerValue == null) {
          await _respond(request, 401, {'error': 'Missing X-Signed-Request header'});
          _log(request.method, request.uri.path, null, 401, 'Missing auth header');
          return null;
        }
        signedReq = SignedRequest.fromJson(jsonDecode(headerValue));
      } else {
        // POST: auth payload is the body
        final bodyStr = await utf8.decoder.bind(request).join();
        signedReq = SignedRequest.fromJson(jsonDecode(bodyStr));
      }

      // Validate timestamp
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final tolerance = _core.settings.current.apiTimestampTolerance;
      if ((now - signedReq.timestamp).abs() > tolerance) {
        await _respond(request, 401, {'error': 'Timestamp out of range'});
        _log(request.method, request.uri.path, signedReq.client, 401, 'Timestamp expired');
        return null;
      }

      // Anti-replay check
      if (_usedSignatures.containsKey(signedReq.signature)) {
        await _respond(request, 401, {'error': 'Signature already used'});
        _log(request.method, request.uri.path, signedReq.client, 401, 'Replay detected');
        return null;
      }

      // Verify signature and recover address
      final recovered = Eip191Verifier.verifyAndRecover(signedReq);
      if (recovered == null) {
        await _respond(request, 401, {'error': 'Invalid signature'});
        _log(request.method, request.uri.path, signedReq.client, 401, 'Invalid signature');
        return null;
      }

      // Check allowlist
      if (!allowedAddresses.contains(recovered.toLowerCase())) {
        await _respond(request, 403, {'error': 'Address not allowed'});
        _log(request.method, request.uri.path, recovered, 403, 'Address not in allowlist');
        return null;
      }

      // Record signature as used
      _usedSignatures[signedReq.signature] = DateTime.now();

      return _AuthResult(recovered, signedReq.data);
    } catch (e) {
      await _respond(request, 401, {'error': 'Auth failed: ${e.toString()}'});
      _log(request.method, request.uri.path, null, 401, 'Auth error: $e');
      return null;
    }
  }

  /// Dispatch to the appropriate handler
  Future<_HandlerResult> _dispatch(
    ApiEndpoint endpoint,
    Map<String, String> params,
    Map<String, dynamic> data,
  ) async {
    switch (endpoint.action) {
      case 'get_state':
        return _getState();
      case 'get_tasks':
        return _getTasks();
      case 'get_task':
        return _getTask(params['id']!);
      case 'run_task':
        return _runTask(params['id']!);
      case 'stop_task':
        return _stopTask(params['id']!);
      case 'kill_task':
        return _killTask(params['id']!);
      case 'input_task':
        return _inputTask(params['id']!, data);
      case 'get_templates':
        return _getTemplates();
      case 'launch_template':
        return _launchTemplate(params['id']!);
      case 'get_layout':
        return _getLayout();
      case 'assign_layout':
        return _assignLayout(data);
      case 'get_history':
        return _getHistory();
      case 'get_resources':
        return _getResources(params['taskId']!);
      default:
        return _HandlerResult.notFound('Unknown action');
    }
  }

  // === HANDLERS ===

  _HandlerResult _getState() {
    return _HandlerResult.ok({
      'tasks': _core.tasks.all.map((t) => t.toJson()).toList(),
      'templates': _core.templates.all.map((t) => t.toJson()).toList(),
      'history': _core.history.all.map((h) => h.toJson()).toList(),
      'layout': {
        'preset': _core.layout.currentPreset.name,
        'slots': _core.layout.slots.map((s) => s.toJson()).toList(),
      },
    });
  }

  _HandlerResult _getTasks() {
    return _HandlerResult.ok({
      'tasks': _core.tasks.all.map((t) => t.toJson()).toList(),
    });
  }

  _HandlerResult _getTask(String id) {
    final task = _core.tasks.getById(id);
    if (task == null) return _HandlerResult.notFound('Task not found');
    return _HandlerResult.ok({
      ...task.toJson(),
      'log': task.logBuffer,
    });
  }

  _HandlerResult _runTask(String id) {
    final task = _core.tasks.getById(id);
    if (task == null) return _HandlerResult.notFound('Task not found');
    if (task.isRunning) return _HandlerResult.conflict('Task already running');
    _core.tasks.run(id);
    return _HandlerResult.ok({'ok': true, 'taskId': id});
  }

  _HandlerResult _stopTask(String id) {
    final task = _core.tasks.getById(id);
    if (task == null) return _HandlerResult.notFound('Task not found');
    if (!task.isRunning) return _HandlerResult.conflict('Task not running');
    _core.tasks.stop(id);
    return _HandlerResult.ok({'ok': true, 'taskId': id});
  }

  _HandlerResult _killTask(String id) {
    final task = _core.tasks.getById(id);
    if (task == null) return _HandlerResult.notFound('Task not found');
    _core.tasks.kill(id);
    return _HandlerResult.ok({'ok': true, 'taskId': id});
  }

  _HandlerResult _inputTask(String id, Map<String, dynamic> data) {
    final task = _core.tasks.getById(id);
    if (task == null) return _HandlerResult.notFound('Task not found');
    if (!task.isRunning) return _HandlerResult.conflict('Task not running');

    final text = data['text'] as String?;
    if (text == null || text.isEmpty) {
      return _HandlerResult.badRequest('Missing "text" field in request data');
    }

    task.write('$text\r\n');
    return _HandlerResult.ok({'ok': true, 'taskId': id});
  }

  _HandlerResult _getTemplates() {
    return _HandlerResult.ok({
      'templates': _core.templates.all.map((t) => t.toJson()).toList(),
    });
  }

  _HandlerResult _launchTemplate(String id) {
    final template = _core.templates.getById(id);
    if (template == null) return _HandlerResult.notFound('Template not found');
    final task = _core.tasks.launch(template);
    return _HandlerResult.ok({'ok': true, 'taskId': task.id});
  }

  _HandlerResult _getLayout() {
    return _HandlerResult.ok({
      'preset': _core.layout.currentPreset.name,
      'slots': _core.layout.slots.map((s) => s.toJson()).toList(),
    });
  }

  _HandlerResult _assignLayout(Map<String, dynamic> data) {
    final slotIndex = data['slotIndex'] as int?;
    final contentType = data['contentType'] as String?;
    final contentId = data['contentId'] as String?;

    if (slotIndex == null || contentType == null) {
      return _HandlerResult.badRequest(
          'Missing required fields: "slotIndex" (int) and "contentType" (string)');
    }

    // Parse content type
    final type = SlotContentType.values
        .where((t) => t.name == contentType)
        .firstOrNull;
    if (type == null) {
      final valid = SlotContentType.values.map((t) => t.name).join(', ');
      return _HandlerResult.badRequest(
          'Invalid contentType "$contentType". Valid: $valid');
    }

    _core.layout.assignSlot(slotIndex, type, contentId);
    return _HandlerResult.ok({
      'ok': true,
      'preset': _core.layout.currentPreset.name,
      'slots': _core.layout.slots.map((s) => s.toJson()).toList(),
    });
  }

  _HandlerResult _getHistory() {
    return _HandlerResult.ok({
      'history': _core.history.all.map((h) => h.toJson()).toList(),
    });
  }

  _HandlerResult _getResources(String taskId) {
    final task = _core.tasks.getById(taskId);
    if (task == null) return _HandlerResult.notFound('Task not found');
    return _HandlerResult.ok({
      'taskId': taskId,
      'latestStats': task.latestStats != null
          ? {
              'pid': task.latestStats!.pid,
              'cpuUsage': task.latestStats!.cpuUsage,
              'memoryUsage': task.latestStats!.memoryUsage,
              'processCount': task.latestStats!.processCount,
              'timestamp': task.latestStats!.timestamp.toIso8601String(),
            }
          : null,
      'statsHistory': task.statsHistory
          .map((s) => {
                'pid': s.pid,
                'cpuUsage': s.cpuUsage,
                'memoryUsage': s.memoryUsage,
                'processCount': s.processCount,
                'timestamp': s.timestamp.toIso8601String(),
              })
          .toList(),
    });
  }

  // === ROUTING ===

  _RouteMatch? _matchRoute(String method, String path) {
    // Strip trailing slash for consistent matching
    final normalizedPath =
        path.length > 1 && path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    for (final ep in endpoints) {
      if (ep.method != method) continue;
      final params = _matchPath(ep.path, normalizedPath);
      if (params != null) {
        return _RouteMatch(ep, params);
      }
    }
    return null;
  }

  /// Match a route pattern against a path, extracting params
  Map<String, String>? _matchPath(String pattern, String path) {
    final patternParts = pattern.split('/');
    final pathParts = path.split('/');
    if (patternParts.length != pathParts.length) return null;

    final params = <String, String>{};
    for (int i = 0; i < patternParts.length; i++) {
      if (patternParts[i].startsWith(':')) {
        params[patternParts[i].substring(1)] = pathParts[i];
      } else if (patternParts[i] != pathParts[i]) {
        return null;
      }
    }
    return params;
  }

  // === HELPERS ===

  Future<void> _respond(HttpRequest request, int statusCode, Map<String, dynamic> body) async {
    request.response.statusCode = statusCode;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  void _log(String method, String path, String? clientAddress, int statusCode, String? error) {
    _requestLog.insert(
      0,
      ApiLogEntry(
        timestamp: DateTime.now(),
        method: method,
        path: path,
        clientAddress: clientAddress,
        statusCode: statusCode,
        error: error,
      ),
    );
    // Trim to max size
    while (_requestLog.length > _maxLogEntries) {
      _requestLog.removeLast();
    }
    _core.notify();
  }

  void _cleanupUsedSignatures() {
    final tolerance = _core.settings.current.apiTimestampTolerance;
    final cutoff = DateTime.now().subtract(Duration(seconds: tolerance * 2));
    _usedSignatures.removeWhere((_, time) => time.isBefore(cutoff));
  }
}

/// Static endpoint definition
class ApiEndpoint {
  final String method;
  final String path;
  final String action;

  const ApiEndpoint(this.method, this.path, this.action);
}

class _RouteMatch {
  final ApiEndpoint endpoint;
  final Map<String, String> params;

  _RouteMatch(this.endpoint, this.params);
}

class _AuthResult {
  final String address;
  final Map<String, dynamic> data;

  _AuthResult(this.address, this.data);
}
