// Diagnostic for the per IP family match attempts in Flinku.match().
//
// Prints the public IP that flku.dev sees for:
//   1. Dart's default connection (what the SDK used before 0.8.0-beta.2),
//   2. a connection pinned to IPv6,
//   3. a connection pinned to IPv4.
// It only calls Cloudflare's /cdn-cgi/trace, never /api/match.
//
// Run from the package root:  dart tool/family_probe.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _timeout = Duration(seconds: 5);
final _uri = Uri.parse('https://flku.dev/cdn-cgi/trace');

Future<String> _traceIp(HttpClient client) async {
  final request = await client.getUrl(_uri).timeout(_timeout);
  final response = await request.close().timeout(_timeout);
  final text = await response.transform(utf8.decoder).join().timeout(_timeout);
  final line = const LineSplitter()
      .convert(text)
      .firstWhere((l) => l.startsWith('ip='), orElse: () => 'ip=(missing)');
  return 'HTTP ${response.statusCode} ${line.trim()}';
}

/// Same connection logic as Flinku._postMatchOverFamily.
Future<HttpClient?> _pinned(InternetAddressType family) async {
  final List<InternetAddress> addresses;
  try {
    addresses =
        await InternetAddress.lookup(_uri.host, type: family).timeout(_timeout);
  } catch (e) {
    stdout.writeln('  lookup failed: $e');
    return null;
  }
  final usable = addresses.where((a) => a.type == family).toList();
  if (usable.isEmpty) return null;
  final target = usable.first;
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 3)
    ..findProxy = (_) => 'DIRECT';
  client.connectionFactory = (Uri url, String? proxyHost, int? proxyPort) async {
    final port = url.hasPort ? url.port : 443;
    final task = await Socket.startConnect(target, port);
    final Future<Socket> secured = task.socket.then<Socket>(
      (raw) => SecureSocket.secure(raw, host: url.host),
    );
    return ConnectionTask.fromSocket(secured, task.cancel);
  };
  return client;
}

Future<void> main() async {
  stdout.writeln('Dart ${Platform.version.split(' ').first} on ${Platform.operatingSystem}');

  final plain = HttpClient();
  try {
    stdout.writeln('default: ${await _traceIp(plain)}');
  } catch (e) {
    stdout.writeln('default: ERROR $e');
  } finally {
    plain.close(force: true);
  }

  for (final family in const [InternetAddressType.IPv6, InternetAddressType.IPv4]) {
    final client = await _pinned(family);
    if (client == null) {
      stdout.writeln('${family.name}: no address for flku.dev');
      continue;
    }
    try {
      stdout.writeln('${family.name}: ${await _traceIp(client)}');
    } catch (e) {
      stdout.writeln('${family.name}: unavailable ($e)');
    } finally {
      client.close(force: true);
    }
  }
}
