class AppConfig {
  const AppConfig._();

  // Defaults to localhost for desktop dev (Windows can reach the NestJS
  // backend directly there) and for the Android emulator's special-cased
  // 10.0.2.2 host alias — neither works for a real Android device on the
  // same LAN or the internet, so release builds targeting a real device
  // must override this at build time:
  //   flutter build appbundle --release --dart-define=API_BASE_URL=https://api.example.com
  // flutter run also accepts --dart-define the same way, e.g. to point a
  // debug build at a backend running on another machine on the LAN.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
}
