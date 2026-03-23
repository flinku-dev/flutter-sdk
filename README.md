# Flinku Flutter SDK

## Installation
Add to pubspec.yaml:
```yaml
dependencies:
  flinku_sdk:
    path: ../flinku_sdk  # local, or git/pub.dev when published
```

## Usage
```dart
// In main()
await Flinku.configure(FlinkuConfig(
  apiKey: 'fku_live_your_key',
  debugMode: true,
));

// Check for deferred deep link once on launch
final link = await Flinku.match();
if (link.matched) {
  // Navigate to link.deepLink
}
```
