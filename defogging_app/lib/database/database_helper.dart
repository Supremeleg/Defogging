import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'location_model.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'locations.db');
    print('Initializing database at $path');
    
    try {
      return await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
        onOpen: (db) async {
          print('Database opened successfully');
          // 验证表是否存在
          var tableExists = await isTableExists(db, 'locations');
          print('Locations table exists: $tableExists');
          
          if (!tableExists) {
            // 如果表不存在，创建表
            await _onCreate(db, 1);
          }
        },
      );
    } catch (e) {
      print('Error opening database: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    print('Creating new database tables at version $version');
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS locations(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          visit_count INTEGER NOT NULL,
          timestamp TEXT NOT NULL
        )
      ''');
      print('Created locations table successfully');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_latitude_longitude ON locations(latitude, longitude)
      ''');
      print('Created index successfully');
    } catch (e) {
      print('Error creating database tables: $e');
      rethrow;
    }
  }

  // 检查表是否存在
  Future<bool> isTableExists(Database db, String tableName) async {
    try {
      var result = await db.query(
        'sqlite_master',
        where: 'type = ? AND name = ?',
        whereArgs: ['table', tableName],
      );
      return result.isNotEmpty;
    } catch (e) {
      print('Error checking if table exists: $e');
      return false;
    }
  }

  // 初始化数据库
  Future<void> initializeDatabase() async {
    try {
      final db = await database;
      var tableExists = await isTableExists(db, 'locations');
      print('Database initialized, locations table exists: $tableExists');
      
      if (!tableExists) {
        // 如果表不存在，尝试创建
        print('Attempting to create locations table');
        await _onCreate(db, 1);
      }
    } catch (e) {
      print('Error initializing database: $e');
      rethrow;
    }
  }

  Future<int> insertLocation(LocationPoint location) async {
    try {
      final db = await database;
      return await db.insert('locations', location.toMap());
    } catch (e) {
      print('Error inserting location: $e');
      rethrow;
    }
  }

  Future<List<LocationPoint>> getAllLocations() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'locations',
        orderBy: 'timestamp DESC',
      );
      return List.generate(maps.length, (i) => LocationPoint.fromMap(maps[i]));
    } catch (e) {
      print('Error getting all locations: $e');
      rethrow;
    }
  }

  Future<int> updateLocation(LocationPoint location) async {
    try {
      final db = await database;
      return await db.update(
        'locations',
        location.toMap(),
        where: 'id = ?',
        whereArgs: [location.id],
      );
    } catch (e) {
      print('Error updating location: $e');
      rethrow;
    }
  }

  Future<LocationPoint?> getLocationByCoordinates(double latitude, double longitude) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'locations',
        where: 'latitude = ? AND longitude = ?',
        whereArgs: [latitude, longitude],
      );
      if (maps.isEmpty) return null;
      return LocationPoint.fromMap(maps.first);
    } catch (e) {
      print('Error getting location by coordinates: $e');
      rethrow;
    }
  }

  Future<void> deleteAllLocations() async {
    try {
      final db = await database;
      await db.delete('locations');
      print('All locations deleted successfully');
    } catch (e) {
      print('Error deleting all locations: $e');
      rethrow;
    }
  }
} 