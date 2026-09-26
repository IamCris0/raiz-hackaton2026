import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/theme/app_theme.dart';
import '../../modules/modulo3_dashboard/db/app_database.dart';
import '../../modules/modulo3_dashboard/models/registro_estudiante.dart';
import '../navigation/app_router.dart';
import 'raiz_widgets.dart';

/// Pantalla principal. Pensada para que un docente sin mucha experiencia
/// digital entienda de un vistazo qué hacer: una acción principal grande
/// (evaluar) y dos herramientas de apoyo.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<ResumenHistorial> _resumen;

  @override
  void initState() {
    super.initState();
    _resumen = AppDatabase.resumen();
  }

  Future<void> _ir(String ruta) async {
    await Navigator.pushNamed(context, ruta);
    if (mounted) setState(() => _resumen = AppDatabase.resumen());
  }

  String get _saludo {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
      body: FutureBuilder<ResumenHistorial>(
        future: _resumen,
        builder: (context, snap) {
          final r = snap.data ?? ResumenHistorial.vacio;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Encabezado(saludo: _saludo)),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -38),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _FilaEstadisticas(resumen: r),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList.list(
                  children: [
                    _TarjetaAccionPrincipal(onTap: () => _ir(AppRouter.captura)),
                    const SizedBox(height: 26),
                    const TituloSeccion('Herramientas'),
                    Row(
                      children: [
                        Expanded(
                          child: _TarjetaHerramienta(
                            icono: Icons.document_scanner_rounded,
                            color: const Color(0xFF3A7BD5),
                            titulo: 'Digitalizar texto',
                            subtitulo: 'Foto → texto editable',
                            onTap: () => _ir(AppRouter.ocr),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TarjetaHerramienta(
                            icono: Icons.insights_rounded,
                            color: const Color(0xFF8E5BD8),
                            titulo: 'Historial',
                            subtitulo: 'Evolución por estudiante',
                            onTap: () => _ir(AppRouter.dashboard),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    TituloSeccion(
                      'Últimas evaluaciones',
                      accion: r.recientes.isEmpty
                          ? null
                          : TextButton(onPressed: () => _ir(AppRouter.dashboard), child: const Text('Ver todo')),
                    ),
                    if (r.recientes.isEmpty)
                      const RaizCard(
                        child: EstadoVacio(
                          icono: Icons.spa_rounded,
                          titulo: 'Aún no hay evaluaciones',
                          mensaje: 'Empieza evaluando la escritura de un estudiante. '
                              'Los resultados se guardan solo en este celular.',
                        ),
                      )
                    else
                      ...r.recientes.map((reg) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _FilaReciente(registro: reg),
                          )),
                    const SizedBox(height: 18),
                    const _NotaEtica(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  final String saludo;
  const _Encabezado({required this.saludo});

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityService>().online;
    final top = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(22, top + 18, 22, 62),
      decoration: const BoxDecoration(
        gradient: AppTheme.gradienteMarca,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -10,
            child: Icon(Icons.spa_rounded, size: 150, color: Colors.white.withValues(alpha: 0.06)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.spa_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    AppConstants.appName,
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                  const Spacer(),
                  _PildoraConexion(online: online),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                '$saludo, docente 👋',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                AppConstants.lema,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 14.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PildoraConexion extends StatelessWidget {
  final bool online;
  const _PildoraConexion({required this.online});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: online ? AppTheme.brote : AppTheme.ambar,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            online ? 'En línea' : 'Sin internet · funciona igual',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _FilaEstadisticas extends StatelessWidget {
  final ResumenHistorial resumen;
  const _FilaEstadisticas({required this.resumen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: AppTheme.bosqueOscuro.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          _Stat(valor: resumen.evaluaciones, etiqueta: 'Evaluaciones', color: AppTheme.bosque),
          _divisor(),
          _Stat(valor: resumen.estudiantes, etiqueta: 'Estudiantes', color: const Color(0xFF3A7BD5)),
          _divisor(),
          _Stat(valor: resumen.alertasAltas, etiqueta: 'Alertas altas', color: AppTheme.riesgoAlto),
        ],
      ),
    );
  }

  Widget _divisor() => Container(width: 1, height: 36, color: AppTheme.borde);
}

class _Stat extends StatelessWidget {
  final int valor;
  final String etiqueta;
  final Color color;
  const _Stat({required this.valor, required this.etiqueta, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$valor', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _TarjetaAccionPrincipal extends StatelessWidget {
  final VoidCallback onTap;
  const _TarjetaAccionPrincipal({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: AppTheme.gradienteAccion,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: AppTheme.bosque.withValues(alpha: 0.30), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.ambar,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('PRINCIPAL',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.bosqueOscuro, letterSpacing: 0.8)),
                    ),
                    const SizedBox(height: 12),
                    const Text('Nueva evaluación',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      'Toma una foto de la escritura del estudiante y obtén una alerta de riesgo en segundos.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13.5, height: 1.35),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_camera_rounded, color: AppTheme.bosque, size: 20),
                          SizedBox(width: 8),
                          Text('Empezar', style: TextStyle(color: AppTheme.bosque, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.draw_rounded, size: 44, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaHerramienta extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _TarjetaHerramienta({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RaizCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconoBurbuja(icono: icono, color: color, tamano: 44),
          const SizedBox(height: 14),
          Text(titulo, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(subtitulo, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _FilaReciente extends StatelessWidget {
  final RegistroEstudiante registro;
  const _FilaReciente({required this.registro});

  @override
  Widget build(BuildContext context) {
    final inicial = registro.nombreEstudiante.trim().isEmpty ? '?' : registro.nombreEstudiante.trim()[0].toUpperCase();
    return RaizCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: registro.nivel.color.withValues(alpha: 0.14),
            child: Text(inicial, style: TextStyle(color: registro.nivel.color, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(registro.nombreEstudiante, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '${registro.grado ?? 'Sin grado'} · ${DateFormat('dd/MM/yyyy').format(registro.fecha)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          InsigniaRiesgo(nivel: registro.nivel, compacta: true),
        ],
      ),
    );
  }
}

class _NotaEtica extends StatelessWidget {
  const _NotaEtica();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_outline_rounded, size: 16, color: AppTheme.tintaSuave),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Los datos de los estudiantes nunca salen de este celular. '
            'Raíz emite alertas de riesgo, no diagnósticos clínicos.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
