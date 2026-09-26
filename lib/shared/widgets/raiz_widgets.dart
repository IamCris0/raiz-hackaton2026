import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../modules/modulo2_deteccion/models/riesgo_resultado.dart';

/// Todo lo visual del semáforo de riesgo en un solo lugar.
extension NivelRiesgoUI on NivelRiesgo {
  Color get color => switch (this) {
        NivelRiesgo.bajo => AppTheme.riesgoBajo,
        NivelRiesgo.medio => AppTheme.riesgoMedio,
        NivelRiesgo.alto => AppTheme.riesgoAlto,
      };

  String get etiqueta => switch (this) {
        NivelRiesgo.bajo => 'Riesgo bajo',
        NivelRiesgo.medio => 'Riesgo moderado',
        NivelRiesgo.alto => 'Riesgo alto',
      };

  String get resumen => switch (this) {
        NivelRiesgo.bajo => 'No se observan señales relevantes en esta muestra.',
        NivelRiesgo.medio => 'Hay señales que conviene observar en las próximas semanas.',
        NivelRiesgo.alto => 'Hay señales importantes: se recomienda derivar a un especialista.',
      };

  IconData get icono => switch (this) {
        NivelRiesgo.bajo => Icons.check_circle_rounded,
        NivelRiesgo.medio => Icons.visibility_rounded,
        NivelRiesgo.alto => Icons.priority_high_rounded,
      };

  List<String> get recomendaciones => switch (this) {
        NivelRiesgo.bajo => [
            'Continuar con las actividades de lectoescritura habituales.',
            'Repetir la evaluación el próximo trimestre para seguir su evolución.',
          ],
        NivelRiesgo.medio => [
            'Observar al estudiante en dictados y lectura en voz alta.',
            'Dar más tiempo en tareas escritas y usar hojas con renglones guía.',
            'Repetir la evaluación en 4–6 semanas y comparar en el historial.',
          ],
        NivelRiesgo.alto => [
            'Informar al DECE o a la autoridad de la institución.',
            'Conversar con la familia y sugerir una valoración profesional.',
            'Mientras tanto: instrucciones cortas, apoyo visual y evaluación oral.',
          ],
      };
}

/// Tarjeta blanca redondeada, la base de casi todo en Raíz.
class RaizCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  const RaizCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borde),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Ícono dentro de un círculo de color suave.
class IconoBurbuja extends StatelessWidget {
  final IconData icono;
  final Color color;
  final double tamano;

  const IconoBurbuja({super.key, required this.icono, required this.color, this.tamano = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(tamano * 0.32),
      ),
      child: Icon(icono, color: color, size: tamano * 0.52),
    );
  }
}

class TituloSeccion extends StatelessWidget {
  final String texto;
  final Widget? accion;

  const TituloSeccion(this.texto, {super.key, this.accion});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.titleMedium)),
          if (accion != null) accion!,
        ],
      ),
    );
  }
}

/// Pastilla de color con el nivel de riesgo.
class InsigniaRiesgo extends StatelessWidget {
  final NivelRiesgo nivel;
  final bool compacta;

  const InsigniaRiesgo({super.key, required this.nivel, this.compacta = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compacta ? 8 : 12, vertical: compacta ? 4 : 6),
      decoration: BoxDecoration(
        color: nivel.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(nivel.icono, size: compacta ? 13 : 16, color: nivel.color),
          const SizedBox(width: 4),
          Text(
            nivel.etiqueta,
            style: TextStyle(
              color: nivel.color,
              fontWeight: FontWeight.w700,
              fontSize: compacta ? 11.5 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso ético obligatorio junto a cualquier resultado.
class AvisoEtico extends StatelessWidget {
  const AvisoEtico({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.ambar.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFB9761A), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppConstants.avisoNoDiagnostico,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF7A4F12)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Medidor circular animado (0–100) para el puntaje de riesgo.
class MedidorRiesgo extends StatelessWidget {
  final double valor; // 0.0 – 1.0
  final Color color;
  final double tamano;

  const MedidorRiesgo({super.key, required this.valor, required this.color, this.tamano = 190});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: valor.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return SizedBox(
          width: tamano,
          height: tamano,
          child: CustomPaint(
            painter: _MedidorPainter(valor: v, color: color),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(v * 100).round()}',
                    style: TextStyle(fontSize: tamano * 0.26, fontWeight: FontWeight.w800, color: AppTheme.tinta, height: 1),
                  ),
                  if (tamano >= 140) ...[
                    const SizedBox(height: 4),
                    const Text('índice de riesgo', style: TextStyle(fontSize: 12, color: AppTheme.tintaSuave)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MedidorPainter extends CustomPainter {
  final double valor;
  final Color color;

  _MedidorPainter({required this.valor, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const inicio = math.pi * 0.75;
    const barrido = math.pi * 1.5;
    final grosor = size.width * 0.085;
    final rect = Rect.fromLTWH(grosor / 2, grosor / 2, size.width - grosor, size.height - grosor);

    final fondo = Paint()
      ..color = AppTheme.borde
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, inicio, barrido, false, fondo);

    final frente = Paint()
      ..shader = SweepGradient(
        startAngle: inicio,
        endAngle: inicio + barrido,
        colors: [color.withValues(alpha: 0.55), color],
        transform: const GradientRotation(0),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    if (valor > 0) canvas.drawArc(rect, inicio, barrido * valor, false, frente);
  }

  @override
  bool shouldRepaint(covariant _MedidorPainter old) => old.valor != valor || old.color != color;
}

/// Estado vacío amable (sin datos todavía).
class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String mensaje;

  const EstadoVacio({super.key, required this.icono, required this.titulo, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      child: Column(
        children: [
          IconoBurbuja(icono: icono, color: AppTheme.bosque, tamano: 64),
          const SizedBox(height: 14),
          Text(titulo, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(mensaje, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
