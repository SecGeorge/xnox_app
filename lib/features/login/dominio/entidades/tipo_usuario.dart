import 'package:flutter/material.dart';

/// Tipo de usuario que inicia sesión en la app.
enum TipoUsuario {
  administrador,
  cliente;

  String get etiqueta {
    switch (this) {
      case TipoUsuario.administrador:
        return 'Administrador';
      case TipoUsuario.cliente:
        return 'Cliente';
    }
  }

  /// Valor enviado al backend.
  String get codigo {
    switch (this) {
      case TipoUsuario.administrador:
        return 'administrador';
      case TipoUsuario.cliente:
        return 'cliente';
    }
  }

  IconData get icono {
    switch (this) {
      case TipoUsuario.administrador:
        return Icons.admin_panel_settings_outlined;
      case TipoUsuario.cliente:
        return Icons.person_outline;
    }
  }

  static TipoUsuario desdeTexto(String? valor) {
    return valor?.toLowerCase() == 'cliente'
        ? TipoUsuario.cliente
        : TipoUsuario.administrador;
  }
}
