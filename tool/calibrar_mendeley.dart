// Calibra el analizador de escritura con el "Potential Dysgraphia Handwriting
// Dataset of School-Age Children" (Mendeley Data, 39hr8dx76p). El dataset no
// se sube al repo: descárgalo y pasa su carpeta como argumento.
//
//   dart run tool/calibrar_mendeley.dart "<ruta>/DATASET DYSGRAPHIA HANDWRITING"
//
// Las imágenes vienen binarizadas (tinta blanca sobre negro) y con un solo
// renglón, así que se invierten y se les agrega margen antes de medir.
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:raiz_app/modules/modulo2_deteccion/analizador_escritura.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Uso: dart run tool/calibrar_mendeley.dart "<carpeta DATASET DYSGRAPHIA HANDWRITING>"');
    exit(64);
  }
  final base = args.first;
  final clases = {
    'Low Potential Dysgraphia': 0,
    'Potential Dysgraphia': 1,
  };

  final filas = <_Fila>[];
  var descartadas = 0;
  for (final MapEntry(key: carpeta, value: etiqueta) in clases.entries) {
    final archivos = Directory('$base/$carpeta').listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in archivos) {
      final original = img.decodeImage(f.readAsBytesSync());
      if (original == null) continue;
      try {
        final m = AnalizadorEscritura.medir(_comoHoja(original), minRenglones: 1, minTrazos: 5);
        filas.add(_Fila(f.uri.pathSegments.last, etiqueta, m));
      } on EscrituraInsuficienteException {
        descartadas++;
      }
    }
  }

  stdout.writeln('Medidas: ${filas.length} imágenes (descartadas: $descartadas)\n');
  stdout.writeln('indicador   mediana_bajo  mediana_posible  AUC');
  final indicadores = <String, double Function(MedidasEscritura)>{
    'tamano': (m) => m.tamano,
    'espaciado': (m) => m.espaciado,
    'lineaBase': (m) => m.lineaBase,
  };
  for (final MapEntry(key: nombre, value: f) in indicadores.entries) {
    final bajo = filas.where((r) => r.clase == 0).map((r) => f(r.m)).toList();
    final posible = filas.where((r) => r.clase == 1).map((r) => f(r.m)).toList();
    stdout.writeln('${nombre.padRight(11)} ${_mediana(bajo).toStringAsFixed(3).padLeft(12)}'
        '  ${_mediana(posible).toStringAsFixed(3).padLeft(15)}  ${_auc(bajo, posible).toStringAsFixed(3)}');
  }

  // Puntaje combinado con los umbrales y pesos actuales de la app
  // (deteccion_service.dart). Se copia aquí porque ese archivo usa Flutter.
  double escalar(double v, double normal, double alto) => ((v - normal) / (alto - normal)).clamp(0.0, 1.0);
  double puntajeApp(MedidasEscritura m) =>
      0.0 * escalar(m.tamano, 0.227, 0.401) + 0.1 * escalar(m.espaciado, 0.258, 0.622) + 0.9 * escalar(m.lineaBase, 0.120, 0.221);
  _reportarPuntaje('Puntaje de la app (umbrales actuales)', filas, puntajeApp, corteApp: 0.25);

  _validacionCruzada(filas);

  final csv = File('build/calibracion_mendeley.csv')..createSync(recursive: true);
  csv.writeAsStringSync([
    'archivo,clase,renglones,trazos,tamano,espaciado,lineaBase',
    for (final r in filas)
      '"${r.archivo}",${r.clase},${r.m.renglones},${r.m.trazos},'
          '${r.m.tamano},${r.m.espaciado},${r.m.lineaBase}',
  ].join('\n'));
  stdout.writeln('\nDetalle por imagen: ${csv.path}');
}

void _reportarPuntaje(String titulo, List<_Fila> filas, double Function(MedidasEscritura) f, {required double corteApp}) {
  final bajo = filas.where((r) => r.clase == 0).map((r) => f(r.m)).toList();
  final posible = filas.where((r) => r.clase == 1).map((r) => f(r.m)).toList();
  stdout.writeln('\n$titulo');
  stdout.writeln('  AUC: ${_auc(bajo, posible).toStringAsFixed(3)}');

  void matriz(double corte, String nombre) {
    final vp = posible.where((p) => p >= corte).length;
    final fp = bajo.where((b) => b >= corte).length;
    final vn = bajo.length - fp;
    final acc = (vp + vn) / (bajo.length + posible.length);
    stdout.writeln('  $nombre (corte ${corte.toStringAsFixed(3)}): acierto ${(acc * 100).toStringAsFixed(1)} %'
        ' · detecta $vp/${posible.length} posibles · falsas alarmas $fp/${bajo.length} bajos');
  }

  matriz(corteApp, 'Corte de la app "no bajo"');
  final candidatos = {...bajo, ...posible}.toList()..sort();
  var mejor = candidatos.first, mejorAcc = 0.0;
  for (final c in candidatos) {
    final acc = (posible.where((p) => p >= c).length + bajo.where((b) => b < c).length) / (bajo.length + posible.length);
    if (acc > mejorAcc) {
      mejorAcc = acc;
      mejor = c;
    }
  }
  matriz(mejor, 'Mejor corte posible');
}

typedef _Rango = ({double normal, double alto});
typedef _Modelo = ({_Rango tamano, _Rango espaciado, _Rango lineaBase, List<double> pesos, double corte});

double _percentil(List<double> v, double p) {
  final s = [...v]..sort();
  final pos = (s.length - 1) * p;
  final i = pos.floor(), j = pos.ceil();
  return s[i] + (s[j] - s[i]) * (pos - i);
}

double _puntaje(_Modelo mod, MedidasEscritura m) {
  double esc(double v, _Rango r) => ((v - r.normal) / (r.alto - r.normal)).clamp(0.0, 1.0);
  return mod.pesos[0] * esc(m.tamano, mod.tamano) +
      mod.pesos[1] * esc(m.espaciado, mod.espaciado) +
      mod.pesos[2] * esc(m.lineaBase, mod.lineaBase);
}

double _aciertoBalanceado(_Modelo mod, List<_Fila> filas) {
  final bajo = filas.where((r) => r.clase == 0);
  final posible = filas.where((r) => r.clase == 1);
  final sens = posible.where((r) => _puntaje(mod, r.m) >= mod.corte).length / posible.length;
  final esp = bajo.where((r) => _puntaje(mod, r.m) < mod.corte).length / bajo.length;
  return (sens + esp) / 2;
}

/// Umbrales desde los niños de bajo riesgo (normal = mediana, alto = p95);
/// pesos (rejilla de 0.1) y corte elegidos por acierto balanceado.
_Modelo _ajustar(List<_Fila> entrenamiento) {
  final bajo = entrenamiento.where((r) => r.clase == 0).map((r) => r.m).toList();
  _Rango rango(double Function(MedidasEscritura) f) {
    final v = bajo.map(f).toList();
    return (normal: _percentil(v, 0.5), alto: _percentil(v, 0.95));
  }

  final t = rango((m) => m.tamano), e = rango((m) => m.espaciado), l = rango((m) => m.lineaBase);
  _Modelo? mejor;
  var mejorAcc = -1.0;
  for (var a = 0; a <= 10; a++) {
    for (var b = 0; a + b <= 10; b++) {
      final pesos = [a / 10, b / 10, (10 - a - b) / 10];
      for (var c = 1; c <= 60; c++) {
        final mod = (tamano: t, espaciado: e, lineaBase: l, pesos: pesos, corte: c / 100);
        final acc = _aciertoBalanceado(mod, entrenamiento);
        if (acc > mejorAcc) {
          mejorAcc = acc;
          mejor = mod;
        }
      }
    }
  }
  return mejor!;
}

void _validacionCruzada(List<_Fila> filas) {
  const k = 5;
  final mezcladas = [...filas]..shuffle(Random(42));
  var vp = 0, fn = 0, fp = 0, vn = 0;
  for (var i = 0; i < k; i++) {
    final prueba = [for (var j = i; j < mezcladas.length; j += k) mezcladas[j]];
    final entrenamiento = [for (var j = 0; j < mezcladas.length; j++) if (j % k != i) mezcladas[j]];
    final mod = _ajustar(entrenamiento);
    for (final r in prueba) {
      final alerta = _puntaje(mod, r.m) >= mod.corte;
      if (r.clase == 1) {
        alerta ? vp++ : fn++;
      } else {
        alerta ? fp++ : vn++;
      }
    }
  }
  final total = vp + fn + fp + vn;
  stdout.writeln('\nRecalibrado — validación cruzada 5 partes (medido en fotos NO usadas para ajustar)');
  stdout.writeln('  acierto ${((vp + vn) / total * 100).toStringAsFixed(1)} %'
      ' · detecta $vp/${vp + fn} posibles (${(vp / (vp + fn) * 100).toStringAsFixed(0)} %)'
      ' · falsas alarmas $fp/${fp + vn} bajos (${(fp / (fp + vn) * 100).toStringAsFixed(0)} %)');

  final finalMod = _ajustar(filas);
  String r(_Rango x) => '(normal: ${x.normal.toStringAsFixed(3)}, alto: ${x.alto.toStringAsFixed(3)})';
  stdout.writeln('\nModelo final (ajustado con las ${filas.length} fotos) para la app:');
  stdout.writeln('  _tamano    = ${r(finalMod.tamano)}');
  stdout.writeln('  _espaciado = ${r(finalMod.espaciado)}');
  stdout.writeln('  _lineaBase = ${r(finalMod.lineaBase)}');
  stdout.writeln('  pesos tamaño/espaciado/lineaBase = ${finalMod.pesos}');
  stdout.writeln('  corte de alerta = ${finalMod.corte}');
}

class _Fila {
  final String archivo;
  final int clase;
  final MedidasEscritura m;
  _Fila(this.archivo, this.clase, this.m);
}

/// Tinta oscura sobre papel claro, con margen para que ningún trazo toque el
/// borde (el analizador descarta lo que toca los bordes de la foto).
img.Image _comoHoja(img.Image original) {
  final invertida = img.invert(img.grayscale(original.clone()));
  final margen = max(40, (original.height * 0.6).round());
  final hoja = img.Image(width: invertida.width + margen * 2, height: invertida.height + margen * 2);
  img.fill(hoja, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(hoja, invertida, dstX: margen, dstY: margen);
  return hoja;
}

double _mediana(List<double> v) {
  if (v.isEmpty) return double.nan;
  final s = [...v]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}

/// Probabilidad de que una muestra "posible" mida más que una "baja".
/// 0.5 = el indicador no separa las clases; 1.0 = las separa perfecto.
double _auc(List<double> bajo, List<double> posible) {
  var gana = 0.0;
  for (final p in posible) {
    for (final b in bajo) {
      if (p > b) {
        gana += 1;
      } else if (p == b) {
        gana += 0.5;
      }
    }
  }
  return gana / (bajo.length * posible.length);
}
