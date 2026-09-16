import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/category.dart';

/// Admin category management. The rules allow only admins to write categories.
abstract interface class CategoryRepository {
  Stream<List<Category>> watchAll();
  Future<void> create(Category category);
  Future<void> update(Category category);
}

class FirestoreCategoryRepository implements CategoryRepository {
  FirestoreCategoryRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Collections.categories);

  @override
  Stream<List<Category>> watchAll() {
    return _col.snapshots().map((s) =>
        s.docs.map((d) => Category.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));
  }

  @override
  Future<void> create(Category category) => _col.add(category.toMap());

  @override
  Future<void> update(Category category) =>
      _col.doc(category.id).update(category.toMap());
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return FirestoreCategoryRepository(FirebaseFirestore.instance);
});

final allCategoriesProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAll();
});
