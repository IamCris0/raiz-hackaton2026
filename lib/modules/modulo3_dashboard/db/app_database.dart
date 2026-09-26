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
          fecha TEXT NOT NULL
        )
      '''),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE registros ADD COLUMN grado TEXT');
        }
      },
    );
    return _db!;
  }

  static Future<int> guardar(RegistroEstudiante registro) async {
    final db = await _open();
    return db.insert('registros', registro.toMap());
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
    return db.delete('registros', where: 'id = ?', whereArgs: [id]);
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
