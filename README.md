# flinku_sdk

Official Flutter SDK for [Flinku](https://flinku.dev) — deferred deep linking for iOS and Android. The modern replacement for Firebase Dynamic Links.

## Installation

```yaml
dependencies:
  flinku_sdk: ^0.3.1
```

## Setup

Each app on Flinku has its own project with a unique subdomain. Configure the SDK with your project URL from the Flinku dashboard:

```dart
import 'package:flutter/material.dart';
import 'package:flinku_sdk/flinku_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Flinku.configure(baseUrl: 'https://yourapp.flku.dev');
  runApp(const MyApp());
}
```

## Handle deep links

Call `Flinku.match()` once when the app starts — on the splash screen or in `initState`:

```dart
@override
void initState() {
  super.initState();
  _checkDeepLink();
}

Future<void> _checkDeepLink() async {
  final link = await Flinku.match();

  if (link != null) {
    // Navigate to the correct screen
    Navigator.pushNamed(context, link.deepLink!);
  }
}
```

## With authentication flow

Save the link result and navigate after the user logs in:

```dart
// On splash screen — check before login
final link = await Flinku.match();

// After login completes
if (link != null) {
  router.go(link.deepLink!);
} else {
  router.go('/home');
}
```

## Query parameters

Links can carry custom parameters set in the Flinku dashboard:

```dart
final link = await Flinku.match();

if (link != null) {
  final ref = link.params?['ref']; // e.g. 'instagram'
  final promo = link.params?['promo']; // e.g. 'SAVE20'
  final productId = link.params?['productId']; // e.g. '123'
}
```

## iOS setup

Add your project domain to Associated Domains in Xcode:

1. Open Xcode → Your Target → Signing & Capabilities
2. Click + Capability → Associated Domains
3. Add: `applinks:yourapp.flku.dev`

## Android setup

Add intent filters to your `AndroidManifest.xml`:

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https"
        android:host="yourapp.flku.dev" />
</intent-filter>
```

## Resetting (testing only)

```dart
await Flinku.reset(); // clears stored match result
```

## Links

- Website: https://flinku.dev
- Repository: https://github.com/flinku-dev/flutter-sdk
- Issues: https://github.com/flinku-dev/flutter-sdk/issues
