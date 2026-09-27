import 'diccionario.dart';

/// Estado de una palabra después de revisar lo que leyó el OCR.
enum EstadoPalabra {
  /// Existe en el diccionario (o es un número / signo).
  correcta,

  /// Tenía dígitos o símbolos en medio ("c0sa") y se corrigió sola.
  corregidaAuto,

  /// No existe: error del OCR o del estudiante. La decide el docente.
  dudosa,

  /// El docente ya la revisó (aceptó una sugerencia, la editó o la dejó igual).
  revisada,
}

class Palabra {
  /// Signos pegados antes y después ("¿", "," "."), que se conservan tal cual.
  final String prefijo, sufijo;

  /// Lo que leyó el OCR, sin tocar.
  final String leida;

  /// Lo que se muestra y se copia.
  String texto;
  EstadoPalabra estado;
  final List<String> sugerencias;

  Palabra({
    required this.prefijo,
    required this.leida,
    required this.sufijo,
    required this.texto,
    required this.estado,
    this.sugerencias = const [],
  });

  bool get porRevisar => estado == EstadoPalabra.dudosa;

  String get completa => '$prefijo$texto$sufijo';

  /// El docente elige una sugerencia, escribe otra o la deja como estaba.
  void resolver(String nuevo) {
    texto = nuevo;
    estado = EstadoPalabra.revisada;
  }
}

/// Texto del OCR separado en renglones y palabras, con las dudosas marcadas.
class TextoRevisado {
  final List<List<Palabra>> renglones;

  /// De qué imagen salió: 'original' o 'mejorada'.
  final String fuente;

  TextoRevisado(this.renglones, {this.fuente = 'original'});

  Iterable<Palabra> get palabras => renglones.expand((r) => r);

  String get texto => renglones.map((r) => r.map((p) => p.completa).join(' ')).join('\n');

  int get porRevisar => palabras.where((p) => p.porRevisar).length;

  int get corregidasAuto => palabras.where((p) => p.estado == EstadoPalabra.corregidaAuto).length;

  /// Letras de palabras reconocidas (existen o se arreglaron solas).
  int get letrasReconocidas => palabras
      .where((p) => p.estado != EstadoPalabra.dudosa && _tieneLetras(p.leida))
      .fold(0, (s, p) => s + p.texto.length);

  /// 0–1: qué parte del texto (por letras) son palabras reconocidas.
  double get calidad {
    final total = palabras.where((p) => _tieneLetras(p.leida)).fold(0, (s, p) => s + p.leida.length);
    return total == 0 ? 0 : letrasReconocidas / total;
  }
}

final _prefijo = RegExp(r'^[¿¡"“«(\[\-–—]+');
final _sufijo = RegExp(r'[.,;:?!"”»)\]…\-–—]+$');
final _letra = RegExp(r'[a-zA-ZáéíóúüñÁÉÍÓÚÜÑ]');

bool _tieneLetras(String s) => _letra.hasMatch(s);

/// Revisa el texto crudo del OCR. Nunca "corrige" la ortografía del
/// estudiante: solo arregla dígitos/símbolos imposibles y marca lo demás.
TextoRevisado revisarTexto(String texto, Diccionario dic, {String fuente = 'original'}) {
  final cache = <String, List<String>>{};
  final renglones = <List<Palabra>>[];

  for (final linea in texto.split('\n')) {
    final fila = <Palabra>[];
    for (final token in linea.split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      final pre = _prefijo.firstMatch(token)?.group(0) ?? '';
      final resto = token.substring(pre.length);
      final suf = _sufijo.firstMatch(resto)?.group(0) ?? '';
      final nucleo = resto.substring(0, resto.length - suf.length);

      Palabra palabra(String t, EstadoPalabra e, [List<String> s = const []]) =>
          Palabra(prefijo: pre, leida: nucleo, sufijo: suf, texto: t, estado: e, sugerencias: s);

      if (nucleo.isEmpty || !_tieneLetras(nucleo) || dic.conoce(nucleo)) {
        fila.add(palabra(nucleo, EstadoPalabra.correcta));
        continue;
      }
      final arreglo = dic.arregloSeguro(nucleo);
      if (arreglo != null) {
        fila.add(palabra(conMayusculas(arreglo, nucleo), EstadoPalabra.corregidaAuto));
        continue;
      }
      final clave = nucleo.toLowerCase();
      final sugerencias = cache.putIfAbsent(clave, () => dic.sugerencias(clave));
      fila.add(palabra(nucleo, EstadoPalabra.dudosa, [for (final s in sugerencias) conMayusculas(s, nucleo)]));
    }
    if (fila.isNotEmpty) renglones.add(fila);
  }
  return TextoRevisado(renglones, fuente: fuente);
}

/// Copia el uso de mayúsculas de [modelo] a [palabra]: "Casa", "CASA" o "casa".
String conMayusculas(String palabra, String modelo) {
  if (palabra.isEmpty || modelo.isEmpty) return palabra;
  final letras = modelo.split('').where(_letra.hasMatch).toList();
  if (letras.length > 1 && letras.every((c) => c == c.toUpperCase())) return palabra.toUpperCase();
  if (letras.isNotEmpty && letras.first == letras.first.toUpperCase()) {
    return palabra[0].toUpperCase() + palabra.substring(1);
  }
  return palabra;
}
