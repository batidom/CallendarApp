class AppConfig {
  const AppConfig._();

  // Windows desktop can reach the NestJS backend directly via localhost.
  // Update this if the backend is hosted elsewhere.
  static const String apiBaseUrl = 'http://localhost:3000';
}
