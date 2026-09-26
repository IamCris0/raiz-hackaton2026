import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
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
          nivel TEXT NOT NULL,
          puntaje REAL NOT NULL,
          fecha TEXT NOT NULL
        )
      '''),
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
}
