import 'dart:convert';

import 'package:http/http.dart' as http;

import 'flinku_config.dart';

class FlinkuHttp {
  FlinkuHttp(this._config);

  final FlinkuConfig _config;

  Future<Map<String, dynamic>> match({
    required String userAgent,
    String? ip,
  }) async {
    final body = {
      'subdomain': _config.subdomain,
      'userAgent': userAgent,
      if (ip != null) 'ip': ip,
    };

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse('${_config.baseUrl}/api/match'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(_config.timeout);

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
        return {'matched': false};
      } catch (_) {
        if (attempt == 1) return {'matched': false};
      }
    }
    return {'matched': false};
  }
}
