import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Medidas crudas de una muestra de escritura. Son relativas a la altura
/// típica de las letras, así que no dependen de qué tan cerca se tomó la foto.
class MedidasEscritura {
  final int renglones;
  final int trazos;

  /// Irregularidad del tamaño de letra (dentro y entre renglones).
  final double tamano;

  /// Dispersión (rango intercuartil relativo) de los espacios entre palabras.
  final double espaciado;

  /// Cuánto suben y bajan las letras respecto a la línea base del renglón.
  final double lineaBase;

  const MedidasEscritura({
    required this.renglones,
    required this.trazos,
    required this.tamano,
    required this.espaciado,
    required this.lineaBase,
  });

  @override
  String toString() => 'renglones=$renglones trazos=$trazos '
      'tamano=${tamano.toStringAsFixed(3)} '
      'espaciado=${espaciado.toStringAsFixed(3)} '
      'lineaBase=${lineaBase.toStringAsFixed(3)}';
}

class EscrituraInsuficienteException implements Exception {
  final String mensaje;
  const EscrituraInsuficienteException(this.mensaje);

  @override
  String toString() => mensaje;
}

class _Trazo {
  int minX, maxX, minY, maxY, area = 0;
  _Trazo(int x, int y)
      : minX = x,
        maxX = x,
        minY = y,
        maxY = y;

  int get alto => maxY - minY + 1;
  int get ancho => maxX - minX + 1;
  double get cx => (minX + maxX) / 2;
  double get cy => (minY + maxY) / 2;
}

/// Extrae medidas de disgrafía de una foto de una hoja escrita a mano.
///
/// Pensado para fotos reales de cuadernos: ignora las líneas impresas del
/// cuaderno, el margen, las mayúsculas de color y los dibujos grandes.
class AnalizadorEscritura {
  static const _anchoTrabajo = 1000;
  static const _minRenglones = 2;
  static const _minTrazos = 20;

  static MedidasEscritura medir(img.Image original) {
    final renglones = _bloquePrincipal(_procesar(original).renglones);

    final totalTrazos = renglones.fold<int>(0, (s, r) => s + r.length);
    if (renglones.length < _minRenglones || totalTrazos < _minTrazos) {
      throw const EscrituraInsuficienteException(
        'No se encontró suficiente escritura en la foto. Acércate a la hoja, '
        'con buena luz, y asegúrate de que se vean al menos 3 renglones.',
      );
    }

    return MedidasEscritura(
      renglones: renglones.length,
      trazos: totalTrazos,
      tamano: _medirTamano(renglones),
      espaciado: _medirEspaciado(renglones),
      lineaBase: _medirLineaBase(renglones),
    );
  }

  /// Imagen con un recuadro por trazo detectado, un color por renglón.
  /// Sirve para calibrar con fotos reales y ver qué está midiendo el análisis.
  static img.Image diagnostico(img.Image original) {
    final p = _procesar(original);
    final renglones = _bloquePrincipal(p.renglones);
    final salida = p.imagen.clone();
    const colores = [
      [230, 25, 75], [60, 180, 75], [0, 130, 200], [245, 130, 48],
      [145, 30, 180], [70, 240, 240], [240, 50, 230], [128, 128, 0],
    ];
    for (var i = 0; i < renglones.length; i++) {
      final c = colores[i % colores.length];
      for (final t in renglones[i]) {
        img.drawRect(salida,
            x1: t.minX, y1: t.minY, x2: t.maxX, y2: t.maxY,
            color: img.ColorRgb8(c[0], c[1], c[2]), thickness: 2);
      }
    }
    return salida;
  }

  /// Renglones con aspecto de texto (todos, no solo el bloque principal).
  static ({img.Image imagen, List<List<_Trazo>> renglones}) _procesar(img.Image original) {
    var imagen = img.bakeOrientation(original);
    if (imagen.width > _anchoTrabajo) {
      imagen = img.copyResize(imagen, width: _anchoTrabajo);
    }
    final w = imagen.width, h = imagen.height;

    final tinta = _binarizar(imagen);
    _borrarLineasLargas(tinta, w, h);

    // Segunda pasada: ya conocida la altura típica de letra, se borran
    // también los pedazos de renglón impreso pegados a las letras (más
    // largos que una letra y sin tinta arriba ni abajo).
    final previos = _filtrarTrazos(_componentes(tinta, w, h), w, h);
    if (previos.isNotEmpty) {
      final altoTipico = _mediana(previos.map((t) => t.alto.toDouble()).toList());
      _borrarLineasLargas(tinta, w, h, largoMinimo: max(12, (altoTipico * 1.3).round()), verticales: false);
    }
    final trazos = _filtrarTrazos(_componentes(tinta, w, h), w, h);
    return (imagen: imagen, renglones: _agruparRenglones(trazos, w));
  }

  // ---------------------------------------------------------------------------
  // Preprocesamiento
  // ---------------------------------------------------------------------------

  /// Umbral adaptativo (media local): resiste sombras y luz desigual de una
  /// foto con celular. Descarta colores saturados no azules (margen rojo,
  /// mayúsculas de color, crayones) pero conserva lápiz, tinta negra y azul.
  static Uint8List _binarizar(img.Image im) {
    final w = im.width, h = im.height;
    final lum = Uint8List(w * h);
    final color = Uint8List(w * h);

    for (final p in im) {
      final escala = 255 / p.maxChannelValue;
      final r = p.r * escala, g = p.g * escala, b = p.b * escala;
      final i = p.y * w + p.x;
      lum[i] = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);

      final maxC = max(r, max(g, b)), minC = min(r, min(g, b));
      final sat = maxC == 0 ? 0.0 : (maxC - minC) / maxC;
      if (sat > 0.35 && !(b >= r && b >= g)) color[i] = 1;
    }

    final integral = Int32List((w + 1) * (h + 1));
    for (var y = 0; y < h; y++) {
      var fila = 0;
      for (var x = 0; x < w; x++) {
        fila += lum[y * w + x];
        integral[(y + 1) * (w + 1) + x + 1] = integral[y * (w + 1) + x + 1] + fila;
      }
    }

    final radio = max(8, w ~/ 40);
    final tinta = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      final y0 = max(0, y - radio), y1 = min(h - 1, y + radio);
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        if (color[i] == 1) continue;
        final x0 = max(0, x - radio), x1 = min(w - 1, x + radio);
        final suma = integral[(y1 + 1) * (w + 1) + x1 + 1] -
            integral[y0 * (w + 1) + x1 + 1] -
            integral[(y1 + 1) * (w + 1) + x0] +
            integral[y0 * (w + 1) + x0];
        final media = suma / ((x1 - x0 + 1) * (y1 - y0 + 1));
        if (lum[i] < media * 0.82 && lum[i] < 200) tinta[i] = 1;
      }
    }
    return tinta;
  }

  /// Borra trazos rectos largos y delgados: renglones impresos del cuaderno
  /// (aunque salgan entrecortados en la foto) y la línea del margen.
  static void _borrarLineasLargas(Uint8List tinta, int w, int h, {int? largoMinimo, bool verticales = true}) {
    const huecoPermitido = 3;
    const grosor = 4;
    final largoH = largoMinimo ?? (w * 0.04).round();

    bool delgado(int x, int y) =>
        (y - grosor < 0 || tinta[(y - grosor) * w + x] == 0) &&
        (y + grosor >= h || tinta[(y + grosor) * w + x] == 0);

    for (var y = 0; y < h; y++) {
      var inicio = -1, ultimo = -1;
      for (var x = 0; x <= w; x++) {
        final on = x < w && tinta[y * w + x] == 1;
        if (on) {
          if (inicio < 0) inicio = x;
          ultimo = x;
          continue;
        }
        if (inicio >= 0 && (x - ultimo > huecoPermitido || x == w)) {
          if (ultimo - inicio + 1 >= largoH) {
            var finos = 0, total = 0;
            for (var k = inicio; k <= ultimo; k++) {
              if (tinta[y * w + k] == 0) continue;
              total++;
              if (delgado(k, y)) finos++;
            }
            if (finos >= total * 0.7) {
              for (var k = inicio; k <= ultimo; k++) {
                if (delgado(k, y)) tinta[y * w + k] = 0;
              }
            }
          }
          inicio = -1;
        }
      }
    }

    if (!verticales) return;
    final largoV = (h * 0.08).round();
    for (var x = 0; x < w; x++) {
      var inicio = -1;
      for (var y = 0; y <= h; y++) {
        final on = y < h && tinta[y * w + x] == 1;
        if (on && inicio < 0) inicio = y;
        if (!on && inicio >= 0) {
          if (y - inicio >= largoV) {
            for (var k = inicio; k < y; k++) {
              tinta[k * w + x] = 0;
            }
          }
          inicio = -1;
        }
      }
    }
  }

  static List<_Trazo> _componentes(Uint8List tinta, int w, int h) {
    final visitado = Uint8List(w * h);
    final pila = Int32List(w * h);
    final trazos = <_Trazo>[];

    for (var inicio = 0; inicio < w * h; inicio++) {
      if (tinta[inicio] == 0 || visitado[inicio] == 1) continue;
      final t = _Trazo(inicio % w, inicio ~/ w);
      var tope = 0;
      pila[tope++] = inicio;
      visitado[inicio] = 1;

      while (tope > 0) {
        final i = pila[--tope];
        final x = i % w, y = i ~/ w;
        t.area++;
        if (x < t.minX) t.minX = x;
        if (x > t.maxX) t.maxX = x;
        if (y < t.minY) t.minY = y;
        if (y > t.maxY) t.maxY = y;

        for (var dy = -1; dy <= 1; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= h) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= w) continue;
            final j = ny * w + nx;
            if (tinta[j] == 1 && visitado[j] == 0) {
              visitado[j] = 1;
              pila[tope++] = j;
            }
          }
        }
      }
      if (t.area >= 6) trazos.add(t);
    }
    return trazos;
  }

  /// Quita ruido (puntos, tildes, polvo), figuras grandes (dibujos) y lo que
  /// toca los bordes de la foto (espiral del cuaderno, mesa), usando la
  /// altura típica de letra como referencia.
  static List<_Trazo> _filtrarTrazos(List<_Trazo> trazos, int w, int h) {
    final mx = w * 0.04, my = h * 0.02;
    final candidatos = trazos
        .where((t) =>
            t.area >= 15 &&
            t.alto >= 5 &&
            t.minX > mx &&
            t.maxX < w - mx &&
            t.minY > my &&
            t.maxY < h - my)
        .toList();
    if (candidatos.isEmpty) return const [];
    final altoTipico = _mediana(candidatos.map((t) => t.alto.toDouble()).toList());

    return candidatos
        .where((t) =>
            t.alto >= altoTipico * 0.35 &&
            t.alto <= altoTipico * 3.5 &&
            t.ancho <= altoTipico * 15 &&
            !(t.alto < altoTipico * 0.6 && t.ancho > t.alto * 2.5) &&
            // Un bloque sólido y redondeado es un agujero o mancha, no una
            // letra (una "l" también es sólida, pero es angosta).
            !(t.ancho > t.alto * 0.5 && t.area > t.ancho * t.alto * 0.7))
        .toList();
  }

  static List<List<_Trazo>> _agruparRenglones(List<_Trazo> trazos, int w) {
    if (trazos.isEmpty) return const [];
    final altoTipico = _mediana(trazos.map((t) => t.alto.toDouble()).toList());
    final ordenados = [...trazos]..sort((a, b) => a.cy.compareTo(b.cy));

    final alto = ordenados.last.cy.ceil() + 1;

    // 1. Distancia entre renglones: el desfase vertical en que la densidad de
    //    trazos más se parece a sí misma (autocorrelación).
    final fina = _densidad(ordenados, alto, max(1.5, altoTipico * 0.25));
    var interlinea = altoTipico * 2;
    var mejor = double.negativeInfinity;
    for (var d = (altoTipico * 1.2).round(); d <= (altoTipico * 8).round() && d < alto; d++) {
      var s = 0.0;
      for (var y = 0; y + d < alto; y++) {
        s += fina[y] * fina[y + d];
      }
      s /= (alto - d);
      if (s > mejor) {
        mejor = s;
        interlinea = d.toDouble();
      }
    }

    // 2. Centros de renglón: picos de la densidad suavizada a escala de la
    //    interlínea, así un renglón que sube y baja sigue siendo un solo pico.
    final suave = _densidad(ordenados, alto, interlinea * 0.2);
    final picos = <int>[];
    for (var y = 1; y < alto - 1; y++) {
      if (suave[y] < 1.5 || suave[y] < suave[y - 1] || suave[y] <= suave[y + 1]) continue;
      if (picos.isNotEmpty && y - picos.last < interlinea * 0.5) {
        if (suave[y] > suave[picos.last]) picos[picos.length - 1] = y;
      } else {
        picos.add(y);
      }
    }
    if (picos.isEmpty) return const [];

    // 3. Cada trazo va al renglón más cercano.
    final renglones = List.generate(picos.length, (_) => <_Trazo>[]);
    for (final t in ordenados) {
      var k = 0;
      for (var i = 1; i < picos.length; i++) {
        if ((picos[i] - t.cy).abs() < (picos[k] - t.cy).abs()) k = i;
      }
      if ((picos[k] - t.cy).abs() <= interlinea * 0.6) renglones[k].add(t);
    }
    return renglones.where((r) => _pareceTexto(r, w)).toList();
  }

  /// Los renglones de un dictado están a distancia regular. Un salto grande
  /// separa bloques (fecha arriba, dibujos abajo); se conserva el bloque con
  /// más escritura.
  static List<List<_Trazo>> _bloquePrincipal(List<List<_Trazo>> renglones) {
    if (renglones.length < 3) return renglones;
    double centro(List<_Trazo> r) => _mediana(r.map((t) => t.cy).toList());

    final distancias = [
      for (var i = 1; i < renglones.length; i++) centro(renglones[i]) - centro(renglones[i - 1]),
    ];
    final tipica = _mediana(distancias);

    final bloques = <List<List<_Trazo>>>[
      [renglones.first],
    ];
    for (var i = 1; i < renglones.length; i++) {
      if (distancias[i - 1] > tipica * 2.2) bloques.add([]);
      bloques.last.add(renglones[i]);
    }

    int trazos(List<List<_Trazo>> b) => b.fold(0, (s, r) => s + r.length);
    return bloques.reduce((a, b) => trazos(b) > trazos(a) ? b : a);
  }

  /// Un renglón escrito es largo y con trazos seguidos; lo que queda de un
  /// dibujo son trazos sueltos y dispersos.
  static bool _pareceTexto(List<_Trazo> r, int w) {
    if (r.length < 5) return false;
    final izq = r.map((t) => t.minX).reduce(min);
    final der = r.map((t) => t.maxX).reduce(max);
    final extension = der - izq + 1;
    if (extension < w * 0.25) return false;
    final ocupado = r.fold<int>(0, (s, t) => s + t.ancho);
    return ocupado / extension >= 0.3;
  }

  // ---------------------------------------------------------------------------
  // Indicadores
  // ---------------------------------------------------------------------------

  static double _medirTamano(List<List<_Trazo>> renglones) {
    final medianas = <double>[];
    final dispersiones = <double>[];
    for (final r in renglones) {
      final alturas = r.map((t) => t.alto.toDouble()).toList()..sort();
      final m = _mediana(alturas);
      medianas.add(m);
      dispersiones.add((_percentil(alturas, 0.75) - _percentil(alturas, 0.25)) / m);
    }
    final entreRenglones = _cv(medianas);
    final dentroRenglon = dispersiones.reduce((a, b) => a + b) / dispersiones.length;
    return 0.5 * entreRenglones + 0.5 * dentroRenglon;
  }

  /// Separa espacios entre letras y entre palabras con Otsu 1D (el umbral se
  /// adapta a cada letra: script separado o cursiva) y mide la regularidad de
  /// los espacios entre palabras. Los espacios se topan en 3 alturas de letra
  /// para que uno enorme (margen, marca suelta) no se lleve el umbral.
  static double _medirEspaciado(List<List<_Trazo>> renglones) {
    final gapsPorRenglon = <List<double>>[];
    final todos = <double>[];
    for (final r in renglones) {
      final alto = _mediana(r.map((t) => t.alto.toDouble()).toList());
      final ordenados = [...r]..sort((a, b) => a.minX.compareTo(b.minX));
      final gaps = <double>[];
      for (var i = 1; i < ordenados.length; i++) {
        final g = (ordenados[i].minX - ordenados[i - 1].maxX) / alto;
        if (g > 0) gaps.add(g);
      }
      gapsPorRenglon.add(gaps);
      todos.addAll(gaps);
    }
    if (todos.length < 4) return 0;

    final umbral = _otsu(todos.map((g) => min(g, 3.0)).toList());
    final relativos = <double>[];
    for (final gaps in gapsPorRenglon) {
      final palabras = gaps.where((g) => g > umbral).toList();
      if (palabras.isEmpty) continue;
      final m = _mediana(palabras);
      relativos.addAll(palabras.map((g) => g / m));
    }
    if (relativos.length < 3) return 0;
    // Rango intercuartil y no desviación estándar: una marca suelta en el
    // margen no debe hacer parecer irregular toda la hoja.
    relativos.sort();
    return (_percentil(relativos, 0.75) - _percentil(relativos, 0.25)) / _percentil(relativos, 0.5);
  }

  /// Ajusta una recta a la base de cada renglón (robusta a p, g, j, y) y mide
  /// cuánto se alejan las letras de ella. La inclinación de la foto no cuenta.
  static double _medirLineaBase(List<List<_Trazo>> renglones) {
    final desviaciones = <double>[];
    for (final r in renglones) {
      final alto = _mediana(r.map((t) => t.alto.toDouble()).toList());
      final xs = r.map((t) => t.cx).toList();
      final ys = r.map((t) => t.maxY.toDouble()).toList();

      var usar = List<bool>.filled(r.length, true);
      var (a, b) = _recta(xs, ys, usar);
      for (var iter = 0; iter < 2; iter++) {
        usar = [for (var i = 0; i < r.length; i++) (ys[i] - (a + b * xs[i])).abs() < alto * 0.4];
        if (usar.where((u) => u).length < 3) break;
        (a, b) = _recta(xs, ys, usar);
      }

      final residuos = [for (var i = 0; i < r.length; i++) (ys[i] - (a + b * xs[i])).abs() / alto];
      desviaciones.add(_mediana(residuos));
    }
    return desviaciones.reduce((a, b) => a + b) / desviaciones.length;
  }

  // ---------------------------------------------------------------------------
  // Estadística
  // ---------------------------------------------------------------------------

  static (double, double) _recta(List<double> xs, List<double> ys, List<bool> usar) {
    var n = 0.0, sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
    for (var i = 0; i < xs.length; i++) {
      if (!usar[i]) continue;
      n++;
      sx += xs[i];
      sy += ys[i];
      sxx += xs[i] * xs[i];
      sxy += xs[i] * ys[i];
    }
    final den = n * sxx - sx * sx;
    if (n == 0) return (0, 0);
    if (den.abs() < 1e-9) return (sy / n, 0);
    final b = (n * sxy - sx * sy) / den;
    return ((sy - b * sx) / n, b);
  }

  /// Suma de campanas gaussianas en el centro vertical de cada trazo.
  static Float64List _densidad(List<_Trazo> trazos, int alto, double sigma) {
    final d = Float64List(alto);
    final radio = (sigma * 3).ceil();
    for (final t in trazos) {
      final c = t.cy.round();
      for (var y = max(0, c - radio); y <= min(alto - 1, c + radio); y++) {
        final z = (y - t.cy) / sigma;
        d[y] += exp(-0.5 * z * z);
      }
    }
    return d;
  }

  static double _otsu(List<double> valores) {
    final v = [...valores]..sort();
    final total = v.reduce((a, b) => a + b);
    var mejor = v.first, mejorVar = -1.0, suma = 0.0;
    for (var i = 0; i < v.length - 1; i++) {
      suma += v[i];
      final n0 = i + 1, n1 = v.length - n0;
      final m0 = suma / n0, m1 = (total - suma) / n1;
      final varianza = n0 * n1 * (m0 - m1) * (m0 - m1);
      if (varianza > mejorVar) {
        mejorVar = varianza;
        mejor = (v[i] + v[i + 1]) / 2;
      }
    }
    return mejor;
  }

  static double _mediana(List<double> v) => _percentil([...v]..sort(), 0.5);

  static double _percentil(List<double> ordenados, double p) {
    if (ordenados.isEmpty) return 0;
    final pos = (ordenados.length - 1) * p;
    final i = pos.floor(), j = pos.ceil();
    return ordenados[i] + (ordenados[j] - ordenados[i]) * (pos - i);
  }

  static double _cv(List<double> v) {
    if (v.length < 2) return 0;
    final m = v.reduce((a, b) => a + b) / v.length;
    if (m == 0) return 0;
    final varianza = v.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / v.length;
    return sqrt(varianza) / m;
  }
}
