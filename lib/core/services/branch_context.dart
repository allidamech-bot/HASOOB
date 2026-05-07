import 'package:flutter/foundation.dart';
import '../../data/models/branch_model.dart';
import '../../data/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class BranchContext extends ChangeNotifier {
  static final BranchContext _instance = BranchContext._internal();
  factory BranchContext() => _instance;
  BranchContext._internal();

  BranchModel? _currentBranch;
  List<BranchModel> _availableBranches = [];
  bool _isLoading = false;

  BranchModel? get currentBranch => _currentBranch;
  String? get currentBranchId => _currentBranch?.id;
  List<BranchModel> get availableBranches => _availableBranches;
  bool get isLoading => _isLoading;

  Future<void> init(String businessId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DBHelper.database();
      
      // Ensure at least one main branch exists
      final branchesCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM branches WHERE businessId = ?', [businessId])
      ) ?? 0;

      if (branchesCount == 0) {
        final mainBranchId = 'BR-$businessId-MAIN';
        final now = DateTime.now().toIso8601String();
        await db.insert('branches', {
          'id': mainBranchId,
          'businessId': businessId,
          'name': 'الفرع الرئيسي',
          'code': 'MAIN',
          'is_main_branch': 1,
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        });
      }

      final branchRows = await db.query(
        'branches',
        where: 'businessId = ? AND is_active = 1',
        whereArgs: [businessId],
      );

      _availableBranches = branchRows.map((e) => BranchModel.fromMap(e)).toList();

      if (_availableBranches.isNotEmpty) {
        // Prefer main branch as default
        _currentBranch = _availableBranches.firstWhere(
          (b) => b.isMainBranch,
          orElse: () => _availableBranches.first,
        );
      }
    } catch (e) {
      debugPrint('Error initializing BranchContext: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void switchBranch(BranchModel branch) {
    if (_availableBranches.contains(branch)) {
      _currentBranch = branch;
      notifyListeners();
    }
  }

  Future<void> refreshBranches(String businessId) async {
    final db = await DBHelper.database();
    final branchRows = await db.query(
      'branches',
      where: 'businessId = ? AND is_active = 1',
      whereArgs: [businessId],
    );
    _availableBranches = branchRows.map((e) => BranchModel.fromMap(e)).toList();
    
    // If current branch is no longer available or inactive, switch to main
    if (_currentBranch != null && !_availableBranches.any((b) => b.id == _currentBranch!.id)) {
      if (_availableBranches.isEmpty) {
        _currentBranch = null;
      } else {
        _currentBranch = _availableBranches.firstWhere(
          (b) => b.isMainBranch,
          orElse: () => _availableBranches.first,
        );
      }
    }
    notifyListeners();
  }
}
