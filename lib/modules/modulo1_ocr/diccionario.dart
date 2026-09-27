import 'dart:math';
import 'dart:typed_data';

/// Diccionario de español para revisar lo que lee el OCR, 100% offline.
///
/// Sirve para dos cosas:
/// 1. Saber si una palabra leída existe ([conoce]). Si no existe, lo más
///    probable es que el OCR se haya equivocado… o que el estudiante la
///    haya escrito mal. Por eso la app **marca** la palabra y **sugiere**,
///    pero la decisión es del docente.
/// 2. Sugerir la palabra correcta ([sugerencias]) con una distancia de
///    edición que sabe qué letras confunde el OCR en la letra a mano
///    (a/o, c/e, rn/m, cl/d…) y que casi no penaliza las tildes.
class Diccionario {
  final Map<String, int> _frecuencia;
  final Map<int, List<String>> _porLargo;

  Diccionario._(this._frecuencia, this._porLargo);

  static final _soloLetras = RegExp(r'^[a-záéíóúüñ]+$');

  /// [texto]: una palabra por línea, `palabra frecuencia`, de la más a la
  /// menos frecuente (ver assets/diccionario/).
  factory Diccionario.desdeTexto(String texto, {int maximo = 30000}) {
    final frecuencia = <String, int>{};
    for (final linea in texto.split('\n')) {
      final partes = linea.trim().split(' ');
      if (partes.length != 2) continue;
      final palabra = partes[0].toLowerCase();
      if (!_soloLetras.hasMatch(palabra)) continue;
      frecuencia.putIfAbsent(palabra, () => int.tryParse(partes[1]) ?? 1);
      if (frecuencia.length >= maximo) break;
    }
    final porLargo = <int, List<String>>{};
    for (final p in frecuencia.keys) {
      porLargo.putIfAbsent(p.length, () => []).add(p);
    }
    return Diccionario._(frecuencia, porLargo);
  }

  int get tamano => _frecuencia.length;

  bool conoce(String palabra) => _frecuencia.containsKey(palabra.toLowerCase());

  /// Hasta [n] palabras del diccionario parecidas a [palabra], la más
  /// probable primero (menor distancia; a igualdad, la más frecuente).
  List<String> sugerencias(String palabra, {int n = 3}) {
    final w = palabra.toLowerCase();
    if (w.isEmpty) return const [];
    final tope = w.length <= 4 ? 1.0 : 2.0;
    final candidatos = <(double, String)>[];
    for (var largo = max(1, w.length - 2); largo <= w.length + 2; largo++) {
      for (final c in _porLargo[largo] ?? const <String>[]) {
        final d = distanciaOcr(w, c, tope);
        if (d <= tope) {
          candidatos.add((d - 0.1 * log(_frecuencia[c]! + 1) / ln10, c));
        }
      }
    }
    candidatos.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final c in candidatos.take(n)) c.$2];
  }

  /// Dígitos o símbolos dentro de una palabra ("c0sa", "hoI|a", "ca$a") son
  /// casi siempre errores del OCR, no del estudiante. Se corrigen solos, pero
  /// SOLO si el resultado es una palabra que existe.
  String? arregloSeguro(String palabra) {
    final w = palabra.toLowerCase();
    if (!w.split('').any(_digitos.containsKey)) return null;
    if (!w.split('').any((c) => _letras.contains(c))) return null;
    final r = w.split('').map((c) => _digitos[c] ?? c).join();
    return _frecuencia.containsKey(r) ? r : null;
  }
}

const _letras = 'abcdefghijklmnopqrstuvwxyzáéíóúüñ';

const _digitos = {
  '0': 'o', '1': 'l', '5': 's', '8': 'b', '6': 'g', '9': 'g', '4': 'a',
  '3': 'e', '7': 't', '|': 'l', '!': 'i', r'$': 's', '@': 'a', '€': 'e',
};

const _sinTilde = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};

/// Letras que el OCR suele confundir en letra manuscrita (costo 0,5 en vez de 1).
const _paresConfusos = [
  'ao', 'ae', 'ce', 'il', 'ij', 'uv', 'nh', 'nr', 'gq', 'gy', 'bh', 'tf',
  'ou', 'sz', 'lt', 'mn', 'nu', 'rv', 'ol', 'cl',
];

final Set<String> _confusos = {
  for (final p in _paresConfusos) ...[p, '${p[1]}${p[0]}'],
};

/// Dos letras que el OCR lee en lugar de una (o al revés): "rn" por "m"...
const _bigramas = {
  'rn': 'm', 'cl': 'd', 'ii': 'u', 'vv': 'w', 'nn': 'm', 'll': 'u',
  'ci': 'a', 'li': 'h', 'ri': 'n', 'in': 'm',
};

double _costoCambio(String a, String b) {
  if (a == b) return 0;
  if ((_sinTilde[a] ?? a) == (_sinTilde[b] ?? b)) return 0.15; // solo la tilde
  if (_confusos.contains('$a$b')) return 0.5;
  return 1;
}

/// Distancia de edición ponderada para errores de OCR: cambios, inserciones,
/// borrados, letras intercambiadas y bigramas (rn↔m, cl↔d…). Devuelve un
/// número mayor que [tope] en cuanto sabe que no va a llegar.
double distanciaOcr(String s, String t, double tope) {
  final n = s.length, m = t.length;
  const infinito = 99.0;
  var ante = Float64List(m + 1); // fila i-2
  var prev = Float64List(m + 1); // fila i-1
  var fila = Float64List(m + 1); // fila i
  for (var j = 0; j <= m; j++) {
    prev[j] = j.toDouble();
  }
  var minPrev = 0.0;
  for (var i = 1; i <= n; i++) {
    fila[0] = i.toDouble();
    var minFila = fila[0];
    for (var j = 1; j <= m; j++) {
      var v = min(min(prev[j] + 1, fila[j - 1] + 1), prev[j - 1] + _costoCambio(s[i - 1], t[j - 1]));
      if (i > 1 && j > 1 && s[i - 1] == t[j - 2] && s[i - 2] == t[j - 1]) {
        v = min(v, ante[j - 2] + 0.6);
      }
      if (i > 1 && _bigramas['${s[i - 2]}${s[i - 1]}'] == t[j - 1]) {
        v = min(v, ante[j - 1] + 0.4);
      }
      if (j > 1 && _bigramas['${t[j - 2]}${t[j - 1]}'] == s[i - 1]) {
        v = min(v, prev[j - 2] + 0.4);
      }
      fila[j] = v;
      if (v < minFila) minFila = v;
    }
    // Poda: las transiciones miran hasta 2 filas atrás, así que solo se
    // corta cuando las dos últimas filas ya superan el tope.
    if (minFila > tope && minPrev > tope) return infinito;
    minPrev = minFila;
    final libre = ante;
    ante = prev;
    prev = fila;
    fila = libre;
  }
  return prev[m];
}
