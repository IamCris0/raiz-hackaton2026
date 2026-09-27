import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'analizador_escritura.dart';
import 'models/riesgo_resultado.dart';

/// El núcleo diferenciador de Raíz: analiza una foto de la escritura de un
/// estudiante y devuelve una alerta de riesgo.
///
/// ## Por qué empezar con una heurística y no con un modelo TFLite
/// Entrenar un modelo de visión confiable para dislexia/disgrafía necesita
/// un dataset etiquetado que hoy no existe (menos aún en español). Esta
/// versión mide marcadores de disgrafía conocidos en la literatura
/// (irregularidad del tamaño de letra, del espaciado entre palabras y de la
/// línea base) directamente sobre la foto, 100% en el celular. El roadmap es
/// complementarlo con un modelo `tflite_flutter` entrenado (ver assets/models/).
class DeteccionService {
  /// Punto de entrada único. Cambiar la implementación interna no debería
  /// afectar a quien llama esto desde la UI.
  ///
  /// Lanza [EscrituraInsuficienteException] si la foto no tiene suficiente
  /// escritura para medir: mejor avisar que inventar un resultado.
  Future<RiesgoResultado> analizarFoto(File foto) async {
    final bytes = await foto.readAsBytes();
    // El análisis recorre cada píxel: en otro isolate la UI no se congela.
    return Isolate.run(() => evaluar(bytes));
  }
}

/// Rangos de calibración por indicador: por debajo de `normal` no hay señal,
/// en `alto` o más la señal es máxima.
///
/// Calibrado con 242 escritos de niños de primaria del "Potential Dysgraphia
/// Handwriting Dataset" (Mendeley, ver tool/calibrar_mendeley.dart):
/// `normal` = mediana de los niños de bajo riesgo, `alto` = su percentil 95.
/// Pesos y corte elegidos con validación cruzada: acierto ~68 %, detecta
/// ~56 % de los casos posibles con ~23 % de falsas alarmas (reproducible con
/// el script; cambia un poco al tocar el analizador). La línea base es la
/// señal que más separa (AUC 0.76); el tamaño no aportó en ese dataset de un
/// solo renglón. Falta validar con dictados reales de niños ecuatorianos.
const _tamano = (normal: 0.227, alto: 0.401);
const _espaciado = (normal: 0.258, alto: 0.622);
const _lineaBase = (normal: 0.120, alto: 0.221);
const _pesos = (tamano: 0.0, espaciado: 0.1, lineaBase: 0.9);
const _corteMedio = 0.25;
const _corteAlto = 0.65;

RiesgoResultado evaluar(Uint8List bytes) {
  final imagen = img.decodeImage(bytes);
  if (imagen == null) {
    throw const EscrituraInsuficienteException('No se pudo leer la imagen capturada.');
  }
  final analisis = AnalizadorEscritura.analizar(imagen);
  return interpretar(analisis.medidas, vista: img.encodeJpg(analisis.vista, quality: 85));
}

RiesgoResultado interpretar(MedidasEscritura m, {Uint8List? vista}) {
  double escalar(double valor, ({double normal, double alto}) r) =>
      ((valor - r.normal) / (r.alto - r.normal)).clamp(0.0, 1.0);

  final tamano = escalar(m.tamano, _tamano);
  final espaciado = escalar(m.espaciado, _espaciado);
  final lineaBase = escalar(m.lineaBase, _lineaBase);

  final puntaje = (_pesos.tamano * tamano + _pesos.espaciado * espaciado + _pesos.lineaBase * lineaBase)
      .clamp(0.0, 1.0);
  final nivel = puntaje < _corteMedio
      ? NivelRiesgo.bajo
      : puntaje < _corteAlto
          ? NivelRiesgo.medio
          : NivelRiesgo.alto;

  String? frase(double valor, String fuerte, String leve) =>
      valor >= 0.6 ? fuerte : (valor >= 0.3 ? leve : null);

  final indicadores = [
    (
      peso: _pesos.tamano,
      nombre: 'tamaño',
      frase: frase(tamano, 'El tamaño de las letras cambia mucho, incluso dentro de una misma línea.',
          'El tamaño de las letras es algo irregular.'),
    ),
    (
      peso: _pesos.espaciado,
      nombre: 'espaciado',
      frase: frase(espaciado, 'El espacio entre palabras es muy desigual: algunas quedan pegadas y otras muy separadas.',
          'El espacio entre palabras varía más de lo esperado.'),
    ),
    (
      peso: _pesos.lineaBase,
      nombre: 'alineación',
      frase: frase(lineaBase, 'Las letras suben y bajan: la escritura no sigue la línea del renglón.',
          'Algunas letras se salen un poco de la línea del renglón.'),
    ),
  ];

  // Solo son "señales" los rasgos que mueven el índice. Los que la
  // calibración dejó sin peso se muestran aparte, para que el docente no
  // vea una señal fuerte junto a un riesgo bajo sin entender por qué.
  final cuentan = indicadores.where((i) => i.peso > 0);
  final senales = [for (final i in cuentan) if (i.frase != null) i.frase!];
  if (senales.isEmpty) {
    final nombres = cuentan.map((i) => i.nombre).toList();
    final lista = nombres.length > 1
        ? '${nombres.sublist(0, nombres.length - 1).join(', ')} y ${nombres.last}'
        : nombres.join();
    senales.add('${lista[0].toUpperCase()}${lista.substring(1)} de la escritura se ven regulares.');
  }

  final observaciones = [
    for (final i in indicadores.where((i) => i.peso == 0))
      if (i.frase != null) i.frase!,
  ];
  if (m.renglones < 3) {
    observaciones.add('Se analizaron solo ${m.renglones} renglones: con una muestra más larga el resultado es más confiable.');
  }

  return RiesgoResultado(
      nivel: nivel, puntaje: puntaje, senales: senales, observaciones: observaciones, vista: vista);
}
