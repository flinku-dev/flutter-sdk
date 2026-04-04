import 'package:flutter/material.dart';
import 'package:flinku_sdk/flinku_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure Flinku with your project settings
  Flinku.configure(
    baseUrl: 'https://myapp.flku.dev',
    apiKey: 'flk_live_your_api_key', // optional, for createLink
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flinku Example',
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FlinkuLink? _link;
  String _status = 'Checking for deep link...';

  @override
  void initState() {
    super.initState();
    _matchLink();
  }

  Future<void> _matchLink() async {
    final link = await Flinku.match();
    if (!mounted) return;
    setState(() {
      _link = link;
      _status = link != null
          ? '✅ Link matched: ${link.deepLink}'
          : '❌ No deferred link found';
    });
  }

  Future<void> _resetAndRematch() async {
    await Flinku.reset();
    if (!mounted) return;
    await _matchLink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flinku Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_status),
            if (_link != null) ...[
              const SizedBox(height: 16),
              Text('Deep link: ${_link!.deepLink}'),
              Text('Params: ${_link!.params}'),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _matchLink,
              child: const Text('Re-test match'),
            ),
            ElevatedButton(
              onPressed: _resetAndRematch,
              child: const Text('Reset cache'),
            ),
          ],
        ),
      ),
    );
  }
}
