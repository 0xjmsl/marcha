import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marcha/core/eip191_verifier.dart';

/// The vectors were signed by a Python client (eth_account) with a throwaway
/// key. They prove the two sides build the same message: same keys, same
/// order, same JSON, for an empty payload, a nested one and one with quotes,
/// backslashes and non-ASCII text.
void main() {
  final file = jsonDecode(
          File('test/signed_request_vectors.json').readAsStringSync())
      as Map<String, dynamic>;
  final address = file['address'] as String;
  final vectors = (file['vectors'] as List).cast<Map<String, dynamic>>();

  test('a request signed by the Python client recovers to its signer', () {
    for (final v in vectors) {
      final req = SignedRequest.fromJson(v);
      expect(Eip191Verifier.verifyAndRecover(req), address,
          reason: 'action ${req.action}');
    }
  });

  test('changing anything that was signed breaks the signature', () {
    final v = vectors[1];
    Map<String, dynamic> withField(String k, Object value) =>
        {...v, k: value};

    final changed = [
      withField('action', 'kill_task'),
      withField('path', '/api/tasks/abc/kill'),
      withField('nonce', 'ffffffffffffffffffffffffffffffff'),
      withField('timestamp', (v['timestamp'] as int) + 1),
      withField('data', {'tasks': []}),
    ];
    for (final c in changed) {
      expect(Eip191Verifier.verifyAndRecover(SignedRequest.fromJson(c)), isNull);
    }
  });

  test('an envelope without a nonce or a path is not accepted', () {
    final v = Map<String, dynamic>.from(vectors[0])..remove('nonce');
    expect(() => SignedRequest.fromJson(v), throwsA(anything));
    final w = Map<String, dynamic>.from(vectors[0])..remove('path');
    expect(() => SignedRequest.fromJson(w), throwsA(anything));
  });
}
