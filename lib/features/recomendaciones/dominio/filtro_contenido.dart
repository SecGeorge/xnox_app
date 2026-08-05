/// Validación del texto de una recomendación: rechaza groserías y mensajes
/// basura (teclazos, letras sueltas, texto sin sentido).
///
/// La MISMA lógica está en el backend (`api/Utiles/FiltroContenido.php`). Aquí
/// sirve para avisar al instante mientras se escribe; allá es la que manda,
/// porque esta se salta con cualquier cliente HTTP. Si se cambia una lista,
/// hay que cambiar las dos.
abstract class FiltroContenido {
  /// Aviso que se le muestra a quien intenta mandar una lisura.
  static const avisoGroseria =
      'No se pueden enviar groserías. Escribe tu recomendación con respeto, '
      'que igual la vamos a leer.';

  static const _minCaracteres = 10;

  /// Raíces de groserías. Se comparan contra el INICIO de cada palabra y se
  /// admiten hasta 4 letras de terminación, para que "puta" también atrape
  /// "putazo" pero "disputa" (donde no arranca la palabra) se salve.
  static const _lisuras = <String>[
    'concha', 'conchatumadre', 'conchasumadre', 'conchetumadre',
    'mierda', 'puta', 'puto', 'putamadre', 'cabron', 'cabrona',
    'huevon', 'hueon', 'weon', 'webon', 'ahuevonado',
    'pendejo', 'pendeja', 'verga', 'pinga', 'pichula', 'poto',
    'culo', 'culiao', 'culear', 'carajo', 'chucha', 'choto',
    'cojudo', 'cojuda', 'maricon', 'marica', 'zorra', 'perra',
    'baboso', 'imbecil', 'idiota', 'estupido', 'tarado', 'pelotudo',
    'boludo', 'gilipollas', 'joder', 'jodido', 'jodete', 'coño',
    'mierdero', 'asqueroso', 'malparido', 'hijueputa', 'hijodeputa',
  ];

  /// Abreviaturas. Van por coincidencia EXACTA: con terminaciones libres
  /// atraparían palabras normales ("csm" dentro de nada, pero "ctm" en
  /// "ctmuy" sí molestaría).
  static const _abreviaturas = <String>[
    'ctm', 'csm', 'ptm', 'hdp', 'mrd', 'wbn', 'ctmr', 'qlq', 'hdpt',
  ];

  /// Secuencias típicas de teclado aporreado.
  /// Ojo: las repeticiones ("aaaa") no van aquí, [normalizar] ya las colapsa.
  static const _teclazos = <String>[
    'asdf', 'sdfg', 'qwer', 'wert', 'zxcv', 'xcvb', 'hjkl', 'jklñ',
    'poiu', 'lkjh', 'mnbv', 'ñlkj',
  ];

  /// Devuelve `null` si el texto es aceptable, o el motivo del rechazo.
  static String? validar(String texto) {
    final limpio = texto.trim();

    if (limpio.isEmpty) {
      return 'Escribe tu recomendación antes de enviarla';
    }
    if (limpio.length < _minCaracteres) {
      return 'Cuéntanos un poco más, con al menos $_minCaracteres caracteres';
    }

    final normalizado = normalizar(limpio);

    if (tieneGroseria(normalizado)) return avisoGroseria;
    if (_esBasura(normalizado)) {
      return 'Escribe una recomendación entendible, con palabras reales';
    }

    return null;
  }

  /// Deja el texto comparable: minúsculas, sin tildes y sin los reemplazos
  /// típicos para esquivar filtros (m1erd4, put@, c0ncha). La ñ se conserva
  /// porque distingue "coño" de "cono".
  static String normalizar(String texto) {
    var t = texto.toLowerCase();

    const equivalencias = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      '@': 'a', '4': 'a', '3': 'e', '1': 'i', '!': 'i',
      '0': 'o', '5': 's', '\$': 's', '7': 't', '8': 'b',
    };
    equivalencias.forEach((de, a) => t = t.replaceAll(de, a));

    // Todo lo que no sea letra pasa a ser separador: así "p.u.t.a" y
    // "p u t a" se juntan igual que "puta".
    t = t.replaceAll(RegExp(r'[^a-zñ]+'), ' ');

    // Letras repetidas 3+ veces se reducen a una ("puuuta" -> "puta").
    t = t.replaceAllMapped(RegExp(r'(.)\1{2,}'), (m) => m[1]!);

    return t.trim();
  }

  /// ¿El texto ya normalizado contiene alguna grosería?
  static bool tieneGroseria(String normalizado) {
    final palabras =
        normalizado.split(' ').where((p) => p.isNotEmpty).toList();

    for (final palabra in palabras) {
      if (_abreviaturas.contains(palabra)) return true;

      for (final raiz in _lisuras) {
        if (palabra.startsWith(raiz) && palabra.length - raiz.length <= 4) {
          return true;
        }
      }
    }

    // Segunda pasada sin espacios: cubre las que se escriben separadas para
    // esquivar el filtro ("conchatu madre", "hijo de puta").
    final pegado = normalizado.replaceAll(' ', '');
    for (final raiz in _lisuras) {
      if (raiz.length >= 6 && pegado.contains(raiz)) return true;
    }

    return false;
  }

  /// Mensajes sin contenido real: teclazos, una sola letra repetida, puras
  /// consonantes. No pretende ser perfecto, solo frenar lo evidente.
  static bool _esBasura(String normalizado) {
    final sinEspacios = normalizado.replaceAll(' ', '');
    if (sinEspacios.length < 6) return true;

    // Casi todo el mensaje es la misma letra.
    if (sinEspacios.split('').toSet().length <= 2) return true;

    if (!RegExp(r'[aeiou]').hasMatch(sinEspacios)) return true;

    for (final secuencia in _teclazos) {
      if (sinEspacios.contains(secuencia)) return true;
    }

    final palabras =
        normalizado.split(' ').where((p) => p.length >= 3).toList();

    // Sin al menos dos palabras de verdad no hay recomendación que leer
    // (atrapa los mensajes de puros números o símbolos).
    if (palabras.length < 2) return true;

    // Palabras largas sin ninguna vocal ("sdfghjk"): si son la mayoría, el
    // mensaje no es texto de verdad.
    if (palabras.isNotEmpty) {
      final sinVocales =
          palabras.where((p) => !RegExp(r'[aeiou]').hasMatch(p)).length;
      if (sinVocales / palabras.length > 0.5) return true;
    }

    return false;
  }
}
