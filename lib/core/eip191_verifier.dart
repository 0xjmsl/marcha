import 'dart:convert';
import 'dart:typed_data';
import 'package:web3dart/crypto.dart';

/// Signed request envelope matching the PublicOS feed server format
class SignedRequest {
  final int timestamp;
  final String action;
  final Map<String, dynamic> data;
  final String client;
  final String signature;

  SignedRequest({
    required this.timestamp,
    required this.action,
    required this.data,
    required this.client,
    required this.signature,
  });

  factory SignedRequest.fromJson(Map<String, dynamic> json) {
    return SignedRequest(
      timestamp: json['timestamp'] as int,
      action: json['action'] as String,
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      client: json['client'] as String,
      signature: json['signature'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'action': action,
        'data': data,
        'client': client,
        'signature': signature,
      };
}

/// EIP-191 signature verifier — recovers the signer address from a signed request
class Eip191Verifier {
  /// Verify and recover the signer address from a signed request.
  /// Returns the recovered address (lowercase, with 0x prefix) or null if invalid.
  static String? verifyAndRecover(SignedRequest request) {
    try {
      // Build message in alphabetical key order to match Go's json.Marshal
      final requestData = {
        'action': request.action,
        'client': request.client,
        'data': request.data,
        'timestamp': request.timestamp,
      };
      final messageJson = jsonEncode(requestData);

      // EIP-191 prefix
      final messageBytes = utf8.encode(messageJson);
      final prefix = '\x19Ethereum Signed Message:\n${messageBytes.length}';
      final prefixBytes = utf8.encode(prefix);
      final fullMessage = Uint8List.fromList([...prefixBytes, ...messageBytes]);
      final messageHash = keccak256(fullMessage);

      // Parse signature hex (0x + 64 chars r + 64 chars s + 2 chars v = 132 chars)
      final sigHex = request.signature.startsWith('0x')
          ? request.signature.substring(2)
          : request.signature;
      if (sigHex.length != 130) return null;

      final r = BigInt.parse(sigHex.substring(0, 64), radix: 16);
      final s = BigInt.parse(sigHex.substring(64, 128), radix: 16);
      var v = int.parse(sigHex.substring(128, 130), radix: 16);

      // Normalize v: some signers produce 0/1, others 27/28.
      // web3dart's ecRecover expects 27/28.
      if (v < 27) v += 27;

      final sig = MsgSignature(r, s, v);

      // Recover public key from signature
      final publicKey = ecRecover(messageHash, sig);

      // Derive address from public key (last 20 bytes of keccak256 hash)
      final addressBytes = publicKeyToAddress(publicKey);
      final recoveredAddress =
          '0x${bytesToHex(addressBytes)}';

      // Compare recovered address to declared client (case-insensitive)
      if (recoveredAddress.toLowerCase() != request.client.toLowerCase()) {
        return null;
      }

      return recoveredAddress.toLowerCase();
    } catch (e) {
      return null;
    }
  }
}
