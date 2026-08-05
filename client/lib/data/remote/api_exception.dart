class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.data});

  final String message;
  final int? statusCode;

  /// The raw JSON error body, when the server sent one — lets callers read
  /// structured fields beyond `message` (e.g. auth/login's 403 response
  /// includes a `code` and the `email` that needs verifying).
  final Map<String, dynamic>? data;

  @override
  String toString() => message;
}
