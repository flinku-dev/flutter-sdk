# flinku_sdk

The official Flutter SDK for Flinku, providing deferred deep linking for iOS and Android.

## Features

- Deferred deep linking support for iOS and Android
- Firebase Dynamic Links replacement path
- Simple Flutter-first integration

## Installation

Add `flinku_sdk` to your `pubspec.yaml`:

```yaml
dependencies:
  flinku_sdk: ^0.1.0
```

Then run:

```bash
flutter pub get
```

## Basic Usage

```dart
import 'package:flinku_sdk/flinku_sdk.dart';

Future<void> initFlinku() async {
  await Flinku.configure(
    FlinkuConfig(
      apiKey: 'fku_live_your_key',
      debugMode: true,
    ),
  );

  final link = await Flinku.match();
  if (link.matched) {
    // Navigate using link.deepLink
  }
}
```

## Links

- Website: https://flinku.dev
- Repository: https://github.com/flinku-dev/flutter-sdk
- Issues: https://github.com/flinku-dev/flutter-sdk/issues
