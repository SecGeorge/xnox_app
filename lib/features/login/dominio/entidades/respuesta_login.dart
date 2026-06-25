class RespuestaLogin {
  final bool success;
  final String message;
  final Map<String, dynamic>? userData;

  RespuestaLogin({
    required this.success,
    required this.message,
    this.userData,
  });
}
