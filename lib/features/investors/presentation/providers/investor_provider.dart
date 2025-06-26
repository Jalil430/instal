import 'package:flutter/foundation.dart';
import '../../domain/entities/investor.dart';
import '../../domain/usecases/get_all_investors.dart';
import '../../domain/usecases/create_investor.dart';
import '../../domain/usecases/search_investors.dart';
import '../../domain/repositories/investor_repository.dart';

class InvestorProvider extends ChangeNotifier {
  final InvestorRepository _repository;
  late final GetAllInvestors _getAllInvestors;
  late final CreateInvestor _createInvestor;
  late final SearchInvestors _searchInvestors;

  InvestorProvider(this._repository) {
    _getAllInvestors = GetAllInvestors(_repository);
    _createInvestor = CreateInvestor(_repository);
    _searchInvestors = SearchInvestors(_repository);
  }

  List<Investor> _investors = [];
  List<Investor> _filteredInvestors = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  List<Investor> get investors => _filteredInvestors.isEmpty && _searchQuery.isEmpty 
      ? _investors 
      : _filteredInvestors;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  bool get hasInvestors => _investors.isNotEmpty;

  Future<void> loadInvestors(String userId) async {
    _setLoading(true);
    _setError(null);

    try {
      _investors = await _getAllInvestors(userId);
      if (_searchQuery.isNotEmpty) {
        await _performSearch(userId, _searchQuery);
      } else {
        _filteredInvestors = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createInvestor(Investor investor) async {
    _setLoading(true);
    _setError(null);

    try {
      await _createInvestor(
        userId: investor.userId,
        fullName: investor.fullName,
        investmentAmount: investor.investmentAmount,
        investorPercentage: investor.investorPercentage,
        userPercentage: investor.userPercentage,
      );
      await loadInvestors(investor.userId);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<void> updateInvestor(Investor investor) async {
    _setLoading(true);
    _setError(null);

    try {
      final updatedInvestor = investor.copyWith(updatedAt: DateTime.now());
      await _repository.updateInvestor(updatedInvestor);
      await loadInvestors(investor.userId);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<void> deleteInvestor(String investorId, String userId) async {
    _setLoading(true);
    _setError(null);

    try {
      await _repository.deleteInvestor(investorId);
      await loadInvestors(userId);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<void> searchInvestors(String userId, String query) async {
    _searchQuery = query;
    
    if (query.trim().isEmpty) {
      _filteredInvestors = [];
      notifyListeners();
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      await _performSearch(userId, query);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _performSearch(String userId, String query) async {
    _filteredInvestors = await _searchInvestors(userId, query);
  }

  void clearSearch() {
    _searchQuery = '';
    _filteredInvestors = [];
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  Investor? getInvestorById(String id) {
    try {
      return _investors.firstWhere((investor) => investor.id == id);
    } catch (e) {
      return null;
    }
  }

  void sortInvestors(InvestorSortOption sortOption) {
    switch (sortOption) {
      case InvestorSortOption.nameAZ:
        _investors.sort((a, b) => a.fullName.compareTo(b.fullName));
        _filteredInvestors.sort((a, b) => a.fullName.compareTo(b.fullName));
        break;
      case InvestorSortOption.nameZA:
        _investors.sort((a, b) => b.fullName.compareTo(a.fullName));
        _filteredInvestors.sort((a, b) => b.fullName.compareTo(a.fullName));
        break;
      case InvestorSortOption.createdDateNewest:
        _investors.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _filteredInvestors.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case InvestorSortOption.createdDateOldest:
        _investors.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _filteredInvestors.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case InvestorSortOption.investmentAmountHighest:
        _investors.sort((a, b) => b.investmentAmount.compareTo(a.investmentAmount));
        _filteredInvestors.sort((a, b) => b.investmentAmount.compareTo(a.investmentAmount));
        break;
      case InvestorSortOption.investmentAmountLowest:
        _investors.sort((a, b) => a.investmentAmount.compareTo(b.investmentAmount));
        _filteredInvestors.sort((a, b) => a.investmentAmount.compareTo(b.investmentAmount));
        break;
    }
    notifyListeners();
  }
}

enum InvestorSortOption {
  nameAZ,
  nameZA,
  createdDateNewest,
  createdDateOldest,
  investmentAmountHighest,
  investmentAmountLowest,
} 