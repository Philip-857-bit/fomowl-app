import 'package:fomowl_wallet/services/secure_store.dart';

class MemoryStore implements SecureStore {
  final values = <String, String>{};
  final writes = <String>[];
  bool dropWrites = false;
  bool dropDeletes = false;
  bool failWrites = false;
  @override
  Future<String?> read({required String key}) async => values[key];
  @override
  Future<void> write({required String key, required String value}) async {
    if (failWrites) throw StateError('secret-wrapping-data');
    writes.add(key);
    if (!dropWrites) values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    if (!dropDeletes) values.remove(key);
  }

  @override
  Future<void> deleteAll() async => values.clear();
}
