import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import '../../modulo2_deteccion/models/riesgo_resultado.dart';
import '../models/registro_estudiante.dart';

/// Acceso a la base de datos local (SQLite). Todo el historial vive en el
/// dispositivo del docente — no hay backend ni nube.
class AppDatabase {
  static Database? _db;

  static Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, AppConstants.dbName);

    _db = await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE registros (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre_estudiante TEXT NOT NULL,
          grado TEXT,
          nivel TEXT NOT NULL,
          puntaje REAL NOT NULL,
          fecha TEXT NOT NULL,
          senales TEXT,
          observaciones TEXT,
          vista_ruta TEXT
        )
      '''),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE registros ADD COLUMN grado TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE registros ADD COLUMN senales TEXT');
          await db.execute('ALTER TABLE registros ADD COLUMN observaciones TEXT');
          await db.execute('ALTER TABLE registros ADD COLUMN vista_ruta TEXT');
        }
      },
    );
    return _db!;
  }

  /// La imagen analizada se guarda como archivo en la carpeta privada de la
  /// app (no en SQLite, para que la base no crezca). Solo sale del celular
  /// si el docente comparte un reporte.
  static Future<int> guardar(RegistroEstudiante registro, {Uint8List? vista}) async {
    final db = await _open();
    String? ruta;
    if (vista != null) {
      final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'evaluaciones'));
      await dir.create(recursive: true);
      ruta = p.join(dir.path, '${registro.fecha.millisecondsSinceEpoch}.jpg');
      await File(ruta).writeAsBytes(vista, flush: true);
    }
    final fila = registro.toMap()..['vista_ruta'] = ruta ?? registro.vistaRuta;
    return db.insert('registros', fila);
  }

  static Future<List<RegistroEstudiante>> historialDe(String nombreEstudiante) async {
    final db = await _open();
    final rows = await db.query(
      'registros',
      where: 'nombre_estudiante = ?',
      whereArgs: [nombreEstudiante],
      orderBy: 'fecha ASC',
    );
    return rows.map(RegistroEstudiante.fromMap).toList();
  }

  static Future<List<RegistroEstudiante>> todos() async {
    final db = await _open();
    final rows = await db.query('registros', orderBy: 'fecha DESC');
    return rows.map(RegistroEstudiante.fromMap).toList();
  }

  static Future<int> eliminar(int id) async {
    final db = await _open();
    final filas = await db.query('registros', columns: ['vista_ruta'], where: 'id = ?', whereArgs: [id]);
    final ruta = filas.isEmpty ? null : filas.first['vista_ruta'] as String?;
    final borradas = await db.delete('registros', where: 'id = ?', whereArgs: [id]);
    if (ruta != null) {
      try {
        await File(ruta).delete();
      } on FileSystemException {
        // Ya no estaba: no hay nada que borrar.
      }
    }
    return borradas;
  }

  /// Nunca lanza: si la base no está disponible (p. ej. en tests), devuelve
  /// un resumen vacío para que la pantalla de inicio siempre cargue.
  static Future<ResumenHistorial> resumen() async {
    try {
      final lista = await todos();
      return ResumenHistorial(
        evaluaciones: lista.length,
        estudiantes: lista.map((r) => r.nombreEstudiante.toLowerCase()).toSet().length,
        alertasAltas: lista.where((r) => r.nivel == NivelRiesgo.alto).length,
        recientes: lista.take(3).toList(),
      );
    } catch (_) {
      return ResumenHistorial.vacio;
    }
  }
}
