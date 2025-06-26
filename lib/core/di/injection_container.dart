import 'package:provider/provider.dart';
import '../../shared/database/database_helper.dart';

// Client feature
import '../../features/clients/data/datasources/client_local_datasource.dart';
import '../../features/clients/data/repositories/client_repository_impl.dart';
import '../../features/clients/domain/repositories/client_repository.dart';
import '../../features/clients/presentation/providers/client_provider.dart';

// Investor feature
import '../../features/investors/data/datasources/investor_local_datasource.dart';
import '../../features/investors/data/repositories/investor_repository_impl.dart';
import '../../features/investors/domain/repositories/investor_repository.dart';
import '../../features/investors/presentation/providers/investor_provider.dart';

// Installment feature
import '../../features/installments/data/datasources/installment_local_datasource.dart';
import '../../features/installments/data/repositories/installment_repository_impl.dart';
import '../../features/installments/domain/repositories/installment_repository.dart';
import '../../features/installments/presentation/providers/installment_provider.dart';

class InjectionContainer {
  static final InjectionContainer _instance = InjectionContainer._internal();
  factory InjectionContainer() => _instance;
  InjectionContainer._internal();

  // Database
  late final DatabaseHelper _databaseHelper;

  // Data sources
  late final ClientLocalDataSource _clientLocalDataSource;
  late final InvestorLocalDataSource _investorLocalDataSource;
  late final InstallmentLocalDataSource _installmentLocalDataSource;

  // Repositories
  late final ClientRepository _clientRepository;
  late final InvestorRepository _investorRepository;
  late final InstallmentRepository _installmentRepository;

  // Providers
  late final ClientProvider _clientProvider;
  late final InvestorProvider _investorProvider;
  late final InstallmentProvider _installmentProvider;

  void init() {
    // Initialize database
    _databaseHelper = DatabaseHelper();

    // Initialize data sources
    _clientLocalDataSource = ClientLocalDataSourceImpl(_databaseHelper);
    _investorLocalDataSource = InvestorLocalDataSourceImpl(_databaseHelper);
    _installmentLocalDataSource = InstallmentLocalDataSourceImpl(_databaseHelper);

    // Initialize repositories
    _clientRepository = ClientRepositoryImpl(_clientLocalDataSource);
    _investorRepository = InvestorRepositoryImpl(_investorLocalDataSource);
    _installmentRepository = InstallmentRepositoryImpl(_installmentLocalDataSource);

    // Initialize providers
    _clientProvider = ClientProvider(_clientRepository);
    _investorProvider = InvestorProvider(_investorRepository);
    _installmentProvider = InstallmentProvider(_installmentRepository);
  }

  // Getters for dependencies
  DatabaseHelper get databaseHelper => _databaseHelper;
  
  ClientLocalDataSource get clientLocalDataSource => _clientLocalDataSource;
  InvestorLocalDataSource get investorLocalDataSource => _investorLocalDataSource;
  InstallmentLocalDataSource get installmentLocalDataSource => _installmentLocalDataSource;
  
  ClientRepository get clientRepository => _clientRepository;
  InvestorRepository get investorRepository => _investorRepository;
  InstallmentRepository get installmentRepository => _installmentRepository;
  
  ClientProvider get clientProvider => _clientProvider;
  InvestorProvider get investorProvider => _investorProvider;
  InstallmentProvider get installmentProvider => _installmentProvider;

  // Provider list for MultiProvider
  List<ChangeNotifierProvider> get providers => [
    ChangeNotifierProvider<ClientProvider>.value(value: _clientProvider),
    ChangeNotifierProvider<InvestorProvider>.value(value: _investorProvider),
    ChangeNotifierProvider<InstallmentProvider>.value(value: _installmentProvider),
  ];
} 