import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('ru'), // Russian - main
    Locale('en'), // English - optional
  ];

  // ===== General & Common =====
  String get appTitle => 'Instal';
  String get search => locale.languageCode == 'ru' ? 'Поиск' : 'Search';
  String get add => locale.languageCode == 'ru' ? 'Добавить' : 'Add';
  String get edit => locale.languageCode == 'ru' ? 'Редактировать' : 'Edit';
  String get delete => locale.languageCode == 'ru' ? 'Удалить' : 'Delete';
  String get save => locale.languageCode == 'ru' ? 'Сохранить' : 'Save';
  String get cancel => locale.languageCode == 'ru' ? 'Отмена' : 'Cancel';
  String get close => locale.languageCode == 'ru' ? 'Закрыть' : 'Close';
  String get details => locale.languageCode == 'ru' ? 'Детали' : 'Details';
  String get status => locale.languageCode == 'ru' ? 'Статус' : 'Status';
  String get amount => locale.languageCode == 'ru' ? 'Сумма' : 'Amount';
  String get date => locale.languageCode == 'ru' ? 'Дата' : 'Date';
  String get information =>
      locale.languageCode == 'ru' ? 'Информация' : 'Information';
  String get mainInformation =>
      locale.languageCode == 'ru' ? 'Основная информация' : 'Main Information';
  String get backToList =>
      locale.languageCode == 'ru' ? 'Вернуться к списку' : 'Back to List';
  String get notFound =>
      locale.languageCode == 'ru' ? 'Ничего не найдено' : 'Nothing found';
  String get unknown => locale.languageCode == 'ru' ? 'Неизвестно' : 'Unknown';
  String get empty => locale.languageCode == 'ru' ? 'Пусто' : 'Empty';
  String get leaveEmptyToAuto => locale.languageCode == 'ru'
      ? 'Оставьте пустым для авто-заполнения'
      : 'Leave empty for auto‑filling';

  String get number => locale.languageCode == 'ru' ? 'Номер' : 'Number';

  String get error => locale.languageCode == 'ru' ? 'Ошибка' : 'Error';
  String get lastUpdated =>
      locale.languageCode == 'ru' ? 'Последнее обновление' : 'Last Updated';
  String get noData =>
      locale.languageCode == 'ru' ? 'Нет данных' : 'No data';
  String get selectDate =>
      locale.languageCode == 'ru' ? 'Выберите дату' : 'Select Date';

  // ===== Navigation =====
  String get installments =>
      locale.languageCode == 'ru' ? 'Рассрочки' : 'Installments';
  String get clients => locale.languageCode == 'ru' ? 'Клиенты' : 'Clients';
  String get investors =>
      locale.languageCode == 'ru' ? 'Инвесторы' : 'Investors';
  String get settings => locale.languageCode == 'ru' ? 'Настройки' : 'Settings';
  String get analytics => locale.languageCode == 'ru' ? 'Аналитика' : 'Analytics';

  // ===== Plurals =====
  String get investor_one =>
      locale.languageCode == 'ru' ? 'инвестор' : 'investor';
  String get investor_few =>
      locale.languageCode == 'ru' ? 'инвестора' : 'investors';
  String get investor_many =>
      locale.languageCode == 'ru' ? 'инвесторов' : 'investors';
  String get client_one => locale.languageCode == 'ru' ? 'клиент' : 'client';
  String get client_few => locale.languageCode == 'ru' ? 'клиента' : 'clients';
  String get client_many => locale.languageCode == 'ru' ? 'клиентов' : 'clients';
  String get installment_one =>
      locale.languageCode == 'ru' ? 'рассрочка' : 'installment';
  String get installment_few =>
      locale.languageCode == 'ru' ? 'рассрочки' : 'installments';
  String get installment_many =>
      locale.languageCode == 'ru' ? 'рассрочек' : 'installments';

  String get refresh => locale.languageCode == 'ru' ? 'Обновить' : 'Refresh';


  // ===== Entities (Client, Investor, Installment) =====
  String get client => locale.languageCode == 'ru' ? 'Клиент' : 'Client';
  String get investor => locale.languageCode == 'ru' ? 'Инвестор' : 'Investor';
  String get installment =>
      locale.languageCode == 'ru' ? 'Рассрочка' : 'Installment';
  String get product => locale.languageCode == 'ru' ? 'Товар' : 'Product';

  String get clientDetails =>
      locale.languageCode == 'ru' ? 'Детали клиента' : 'Client Details';
  String get investorDetails =>
      locale.languageCode == 'ru' ? 'Детали инвестора' : 'Investor Details';
  String get installmentDetails =>
      locale.languageCode == 'ru' ? 'Детали рассрочки' : 'Installment Details';

  String get clientInstallments =>
      locale.languageCode == 'ru' ? 'Рассрочки клиента' : 'Client Installments';
  String get investorInstallments =>
      locale.languageCode == 'ru' ? 'Рассрочки инвестора' : 'Investor Installments';

  String get fullName => locale.languageCode == 'ru' ? 'Полное имя' : 'Full Name';
  String get contactNumber =>
      locale.languageCode == 'ru' ? 'Телефон' : 'Phone';
  String get passportNumber =>
      locale.languageCode == 'ru' ? 'Номер паспорта' : 'Passport Number';
  String get address => locale.languageCode == 'ru' ? 'Адрес' : 'Address';
  // Guarantor fields
  String get gurantor => locale.languageCode == 'ru' ? 'Поручитель' : 'Gurantor';
  String get guarantorFullName =>
      locale.languageCode == 'ru' ? 'ФИО поручителя' : 'Guarantor Full Name';
  String get guarantorContactNumber => locale.languageCode == 'ru'
      ? 'Телефон поручителя'
      : 'Guarantor Phone';
  String get guarantorPassportNumber => locale.languageCode == 'ru'
      ? 'Паспорт поручителя'
      : 'Guarantor Passport';
  String get guarantorAddress => locale.languageCode == 'ru'
      ? 'Адрес поручителя'
      : 'Guarantor Address';

  String get investmentAmount =>
      locale.languageCode == 'ru' ? 'Сумма инвестиции' : 'Investment Amount';
  String get investorShare =>
      locale.languageCode == 'ru' ? 'Доля инвестора' : 'Investor Share';
  String get userShare =>
      locale.languageCode == 'ru' ? 'Доля пользователя' : 'User Share';
  String get profitDistribution =>
      locale.languageCode == 'ru' ? 'Распределение прибыли' : 'Profit Distribution';

  String get productName =>
      locale.languageCode == 'ru' ? 'Название товара' : 'Product Name';
  String get cashPrice =>
      locale.languageCode == 'ru' ? 'Цена за наличные' : 'Cash Price';
  String get installmentPrice =>
      locale.languageCode == 'ru' ? 'Цена в рассрочку' : 'Installment Price';
  String get term => locale.languageCode == 'ru' ? 'Срок' : 'Term';
  String get termMonths =>
      locale.languageCode == 'ru' ? 'Срок (месяцы)' : 'Term (months)';
  String get months => locale.languageCode == 'ru' ? 'мес.' : 'months';
  String get downPayment =>
      locale.languageCode == 'ru' ? 'Первоначальный взнос' : 'Down Payment';
  String get downPaymentShort => locale.languageCode == 'ru' ? 'Взнос' : 'Down';
  String get downPaymentFull =>
      locale.languageCode == 'ru' ? 'Первоначальный взнос' : 'Down Payment';
  String get monthlyPayment =>
      locale.languageCode == 'ru' ? 'Ежемесячный платеж' : 'Monthly Payment';
  String get installmentNumber => locale.languageCode == 'ru'
      ? 'Номер рассрочки'
      : 'Installment Number';
  String get buyingDate =>
      locale.languageCode == 'ru' ? 'Дата покупки' : 'Buying Date';
  String get installmentStartDate => locale.languageCode == 'ru'
      ? 'Дата начала рассрочки'
      : 'Installment Start Date';
  String get installmentEndDate => locale.languageCode == 'ru'
      ? 'Дата окончания рассрочки'
      : 'Installment End Date';
  String get paidAmount => locale.languageCode == 'ru' ? 'Оплачено' : 'Paid Amount';
  String get leftAmount => locale.languageCode == 'ru' ? 'Остаток' : 'Remaining';
  String get dueDate => locale.languageCode == 'ru' ? 'Срок оплаты' : 'Due Date';
  String get nextPayment =>
      locale.languageCode == 'ru' ? 'Следующий платеж' : 'Next Payment';

  // ===== Statuses =====
  String get paid => locale.languageCode == 'ru' ? 'Оплачено' : 'Paid';
  String get upcoming =>
      locale.languageCode == 'ru' ? 'Предстоящий' : 'Upcoming';
  String get dueToPay => locale.languageCode == 'ru' ? 'К оплате' : 'Due to Pay';
  String get overdue => locale.languageCode == 'ru' ? 'Просрочено' : 'Overdue';


  String get all => locale.languageCode == 'ru' ? 'Все' : 'All';

  String get filterByStatus => locale.languageCode == 'ru' ? 'Фильтр по статусу' : 'Filter by status';


  // ===== Actions & Buttons =====
  String get addInstallment =>
      locale.languageCode == 'ru' ? 'Добавить рассрочку' : 'Add Installment';
  String get addClient =>
      locale.languageCode == 'ru' ? 'Добавить клиента' : 'Add Client';
  String get addInvestor =>
      locale.languageCode == 'ru' ? 'Добавить инвестора' : 'Add Investor';
  String get editInstallment => locale.languageCode == 'ru'
      ? 'Редактировать рассрочку'
      : 'Edit Installment';
  String get editClient =>
      locale.languageCode == 'ru' ? 'Редактировать клиента' : 'Edit Client';
  String get editInvestor =>
      locale.languageCode == 'ru' ? 'Редактировать инвестора' : 'Edit Investor';
  String get registerPayment =>
      locale.languageCode == 'ru' ? 'Зарегистрировать платеж' : 'Register Payment';
  String get confirm =>
      locale.languageCode == 'ru' ? 'Подтвердить' : 'Confirm';
  String get cancelPayment =>
      locale.languageCode == 'ru' ? 'Отменить платеж' : 'Cancel Payment';
  String get openFolder =>
      locale.languageCode == 'ru' ? 'Открыть папку' : 'Open Folder';
  String get select => locale.languageCode == 'ru' ? 'Выбрать' : 'Select';
  String get deleteAction => locale.languageCode == 'ru' ? 'Удалить' : 'Delete';

  String get clientUpdatedSuccess => locale.languageCode == 'ru'
      ? 'Клиент успешно обновлен'
      : 'Client updated successfully';
  String get clientCreatedSuccess => locale.languageCode == 'ru'
      ? 'Клиент успешно создан'
      : 'Client created successfully';
  String get personalInformation =>
      locale.languageCode == 'ru' ? 'Личная информация' : 'Personal Information';
  String get documentsAndAddress =>
      locale.languageCode == 'ru' ? 'Документы и адрес' : 'Documents & Address';

  String get installmentNotFound =>
      locale.languageCode == 'ru' ? 'Рассрочка не найдена' : 'Installment not found';
  String get noInstallments =>
      locale.languageCode == 'ru' ? 'Нет рассрочек' : 'No installments';
  String get installmentCreatedSuccess => locale.languageCode == 'ru'
      ? 'Рассрочка успешно создана'
      : 'Installment created successfully';
  String get withoutInvestor =>
      locale.languageCode == 'ru' ? 'Без инвестора' : 'Without Investor';
  String get noInvestorsAvailable => locale.languageCode == 'ru'
      ? 'Нет доступных инвесторов'
      : 'No investors available';

  String get userShareHelperText => locale.languageCode == 'ru'
      ? 'Доля пользователя рассчитывается автоматически. Сумма долей должна равняться 100%.'
      : 'User share is calculated automatically. The sum of shares must equal 100%.';

  // ===== Sort Options =====
  String get sortBy => locale.languageCode == 'ru' ? 'Сортировать по' : 'Sort by';
  String get creationDate =>
      locale.languageCode == 'ru' ? 'Дата создания' : 'Creation Date';
  String get sortByName =>
      locale.languageCode == 'ru' ? 'Имени' : 'Name';
  String get sortByInvestment =>
      locale.languageCode == 'ru' ? 'Инвестиции' : 'Investment';
  String get sortByContact =>
      locale.languageCode == 'ru' ? 'Контакту' : 'Contact';

  // ===== Validation Messages =====
  String get fieldRequired =>
      locale.languageCode == 'ru' ? 'Это поле обязательно' : 'This field is required';
  String get invalidNumber =>
      locale.languageCode == 'ru' ? 'Неверный номер' : 'Invalid number';
  String get invalidAmount =>
      locale.languageCode == 'ru' ? 'Неверная сумма' : 'Invalid amount';
  String get enterFullName =>
      locale.languageCode == 'ru' ? 'Введите полное имя' : 'Enter full name';
  String get enterValidInvestmentAmount => locale.languageCode == 'ru'
      ? 'Введите корректную сумму инвестиции'
      : 'Enter a valid investment amount';
  String get enterValidInvestorShare => locale.languageCode == 'ru'
      ? 'Введите корректную долю инвестора'
      : 'Enter a valid investor share';
  String get enterValidUserShare => locale.languageCode == 'ru'
      ? 'Введите корректную долю пользователя'
      : 'Enter a valid user share';
  String get percentageValidation => locale.languageCode == 'ru'
      ? 'Процент должен быть от 0 до 100'
      : 'Percentage must be between 0 and 100';
  String get percentageSumValidation => locale.languageCode == 'ru'
      ? 'Сумма долей должна равняться 100%'
      : 'The sum of shares must be 100%';
  String get enterContactNumber =>
      locale.languageCode == 'ru' ? 'Введите контактный номер' : 'Enter contact number';
  String get enterPassportNumber =>
      locale.languageCode == 'ru' ? 'Введите номер паспорта' : 'Enter passport number';
  String get enterAddress =>
      locale.languageCode == 'ru' ? 'Введите адрес' : 'Enter address';
  String get enterProductName =>
      locale.languageCode == 'ru' ? 'Введите название товара' : 'Enter product name';
  String get enterValidPrice =>
      locale.languageCode == 'ru' ? 'Введите корректную цену' : 'Enter a valid price';
  String get enterValidTerm =>
      locale.languageCode == 'ru' ? 'Введите срок в месяцах' : 'Enter a valid term in months';
  String get enterValidDownPayment => locale.languageCode == 'ru'
      ? 'Введите сумму первоначального взноса'
      : 'Enter a valid down payment amount';
  String get sessionExpired => locale.languageCode == 'ru' 
      ? 'Ваша сессия истекла. Пожалуйста, войдите снова.' 
      : 'Your session has expired. Please log in again.';
  String get validateMonthlyPayment => locale.languageCode == 'ru'
      ? 'Введите сумму ежемесячного платежа'
      : 'Enter a valid monthly payment amount';
  String get selectClientError =>
      locale.languageCode == 'ru' ? 'Выберите клиента' : 'Please select a client';

  // ===== Dialogs & Banners =====
  String get errorLoading =>
      locale.languageCode == 'ru' ? 'Ошибка загрузки' : 'Error loading';
  String get errorLoadingData =>
      locale.languageCode == 'ru' ? 'Ошибка загрузки данных' : 'Error loading data';
  String get errorSaving =>
      locale.languageCode == 'ru' ? 'Ошибка сохранения' : 'Error saving';
  String get errorDeleting =>
      locale.languageCode == 'ru' ? 'Ошибка удаления' : 'Error deleting';
  String get errorCreatingInstallment => locale.languageCode == 'ru'
      ? 'Ошибка создания рассрочки'
      : 'Error creating installment';

  String get cancelPaymentQuestion => locale.languageCode == 'ru'
      ? 'Отменить оплату этого платежа?'
      : 'Cancel payment for this installment?';

  String deleteInvestorConfirmation(String name) => locale.languageCode == 'ru'
      ? 'Вы уверены, что хотите удалить инвестора "$name"?'
      : 'Are you sure you want to delete investor "$name"?';
  String get deleteInvestorTitle =>
      locale.languageCode == 'ru' ? 'Удалить инвестора' : 'Delete Investor';
  String get investorDeleted =>
      locale.languageCode == 'ru' ? 'Инвестор удален' : 'Investor deleted';
  String get investorsDeleted =>
      locale.languageCode == 'ru' ? 'Инвесторы удалены' : 'Investors deleted';
  String get deleteInvestorsConfirmation =>
      locale.languageCode == 'ru' ? 'Вы уверены, что хотите удалить этих инвесторов?' : 'Are you sure you want to delete these investors?';
  String investorDeleteError(Object e) =>
      locale.languageCode == 'ru' ? 'Ошибка удаления инвестора: $e' : 'Error deleting investor: $e';
  String get investorNotFound =>
      locale.languageCode == 'ru' ? 'Инвестор не найден' : 'Investor not found';
  String get investorUpdatedSuccess => locale.languageCode == 'ru'
      ? 'Инвестор успешно обновлен'
      : 'Investor updated successfully';
  String get investorCreatedSuccess => locale.languageCode == 'ru'
      ? 'Инвестор успешно создан'
      : 'Investor created successfully';

  String deleteClientConfirmation(String name) => locale.languageCode == 'ru'
      ? 'Вы уверены, что хотите удалить клиента "$name"?'
      : 'Are you sure you want to delete client "$name"?';
  String get deleteClientTitle =>
      locale.languageCode == 'ru' ? 'Удалить клиента' : 'Delete Client';
  String get clientDeleted =>
      locale.languageCode == 'ru' ? 'Клиент удален' : 'Client deleted';
  String get clientsDeleted =>
      locale.languageCode == 'ru' ? 'Клиенты удалены' : 'Clients deleted';
  String get deleteClientsConfirmation =>
      locale.languageCode == 'ru' ? 'Вы уверены, что хотите удалить этих клиентов?' : 'Are you sure you want to delete these clients?';
  String clientDeleteError(Object e) =>
      locale.languageCode == 'ru' ? 'Ошибка удаления клиента: $e' : 'Error deleting client: $e';
  String get clientNotFound =>
      locale.languageCode == 'ru' ? 'Клиент не найден' : 'Client not found';

  // Table headers and section headers
  String get fullNameHeader =>
      locale.languageCode == 'ru' ? 'ПОЛНОЕ ИМЯ' : 'FULL NAME';
  String get investmentAmountHeader =>
      locale.languageCode == 'ru' ? 'СУММА ИНВЕСТИЦИИ' : 'INVESTMENT AMOUNT';
  String get investorShareHeader =>
      locale.languageCode == 'ru' ? 'ДОЛЯ ИНВЕСТОРА' : 'INVESTOR SHARE';
  String get userShareHeader =>
      locale.languageCode == 'ru' ? 'ДОЛЯ ПОЛЬЗОВАТЕЛЯ' : 'USER SHARE';
  String get creationDateHeader =>
      locale.languageCode == 'ru' ? 'ДАТА СОЗДАНИЯ' : 'CREATION DATE';
  String get contactNumberHeader =>
      locale.languageCode == 'ru' ? 'КОНТАКТНЫЙ НОМЕР' : 'CONTACT NUMBER';
  String get passportNumberHeader =>
      locale.languageCode == 'ru' ? 'НОМЕР ПАСПОРТА' : 'PASSPORT NUMBER';
  String get addressHeader => locale.languageCode == 'ru' ? 'АДРЕС' : 'ADDRESS';
  String get productNameHeader =>
      locale.languageCode == 'ru' ? 'ТОВАР' : 'PRODUCT';
  String get amountHeader => locale.languageCode == 'ru' ? 'СУММА' : 'AMOUNT';
  String get termHeader => locale.languageCode == 'ru' ? 'СРОК' : 'TERM';
  String get buyingDateHeader =>
      locale.languageCode == 'ru' ? 'ДАТА ПОКУПКИ' : 'BUYING DATE';
  String get dateHeader => locale.languageCode == 'ru' ? 'ДАТА' : 'DATE';
  String get scheduleHeader =>
      locale.languageCode == 'ru' ? 'График платежей' : 'Payment Schedule';
  String get financialInfoHeader =>
      locale.languageCode == 'ru' ? 'Финансовая информация' : 'Financial Information';
  String get datesHeader => locale.languageCode == 'ru' ? 'Сроки и даты' : 'Dates';
  String get noPayments =>
      locale.languageCode == 'ru' ? 'Нет платежей' : 'No payments';
  String get noClientsAvailable =>
      locale.languageCode == 'ru' ? 'Нет доступных клиентов' : 'No clients available';
  String get selectClient =>
      locale.languageCode == 'ru' ? 'Выберите клиента' : 'Select a client';
  String get investorOptional =>
      locale.languageCode == 'ru' ? 'Инвестор (необязательно)' : 'Investor (optional)';

  // ===== Wallets =====
  String get wallets => locale.languageCode == 'ru' ? 'Кошельки' : 'Wallets';
  String get wallet => locale.languageCode == 'ru' ? 'Кошелек' : 'Wallet';
  String get walletDetails => locale.languageCode == 'ru' ? 'Детали кошелька' : 'Wallet Details';
  String get walletTransactions => locale.languageCode == 'ru' ? 'Операции кошелька' : 'Wallet Transactions';
  String get withoutWallet => locale.languageCode == 'ru' ? 'Без кошелька' : 'Without wallet';
  String get selectWallet => locale.languageCode == 'ru' ? 'Выберите кошелек' : 'Select wallet';
  String get createWallet => locale.languageCode == 'ru' ? 'Создать кошелек' : 'Create wallet';
  String get walletName => locale.languageCode == 'ru' ? 'Название кошелька' : 'Wallet name';
  String get enterWalletName => locale.languageCode == 'ru' ? 'Введите название кошелька' : 'Enter wallet name';
  String get walletType => locale.languageCode == 'ru' ? 'Тип кошелька' : 'Wallet type';
  String get personal => locale.languageCode == 'ru' ? 'Личный' : 'Personal';
  String get personalWallet => locale.languageCode == 'ru' ? 'Личный кошелек' : 'Personal wallet';
  String get investorWallet => locale.languageCode == 'ru' ? 'Инвестиционный кошелек' : 'Investor wallet';
  String get walletBalance => locale.languageCode == 'ru' ? 'Баланс кошелька' : 'Wallet balance';
  String get walletInfo => locale.languageCode == 'ru' ? 'Информация о кошельке' : 'Wallet Info';
  String get investmentReturnDate => locale.languageCode == 'ru' ? 'Дата возврата инвестиции' : 'Investment Return Date';
  String get investorPercentage => locale.languageCode == 'ru' ? 'Процент инвестора' : 'Investor Percentage';
  String get userPercentage => locale.languageCode == 'ru' ? 'Процент пользователя' : 'User Percentage';
  String get yourPercentage => locale.languageCode == 'ru' ? 'Ваш процент' : 'Your Percentage';
  String get totalBalance => locale.languageCode == 'ru' ? 'Общий баланс' : 'Total balance';


  // Wallet descriptions
  String get personalWalletDescription => locale.languageCode == 'ru' ? 'Для ваших личных средств' : 'For your personal funds';
  String get investorWalletDescription => locale.languageCode == 'ru' ? 'Для инвестиций с доходом' : 'For investments with income';

  // Wallet form labels
  String get creating => locale.languageCode == 'ru' ? 'Создание...' : 'Creating...';
  String get create => locale.languageCode == 'ru' ? 'Создать' : 'Create';
  String get enterName => locale.languageCode == 'ru' ? 'Введите название' : 'Enter name';

  // Wallet validation messages
  String get investmentAmountRequired => locale.languageCode == 'ru' ? 'Сумма инвестиции обязательна' : 'Investment amount is required';
  String get enterValidAmount => locale.languageCode == 'ru' ? 'Введите корректную сумму' : 'Enter a valid amount';
  String get percentageRequired => locale.languageCode == 'ru' ? 'Процент обязателен' : 'Percentage is required';
  String get percentageRange => locale.languageCode == 'ru' ? '0-100' : '0-100';
  String get percentageSum100 => locale.languageCode == 'ru' ? 'Сумма должна быть 100%' : 'Sum must be 100%';

  String get expectedReturns => locale.languageCode == 'ru' ? 'Ожидаемые доходы' : 'Expected returns';
  String get profit => locale.languageCode == 'ru' ? 'Прибыль' : 'Profit';
  String get returnDueDate => locale.languageCode == 'ru' ? 'Дата возврата' : 'Return due date';
  String get nextPaymentHeader =>
      locale.languageCode == 'ru' ? 'СЛЕДУЮЩИЙ ПЛАТЕЖ' : 'NEXT PAYMENT';
  String get paymentHeader =>
      locale.languageCode == 'ru' ? 'ПЛАТЕЖ' : 'PAYMENT';
  String get statusHeader => locale.languageCode == 'ru' ? 'СТАТУС' : 'STATUS';

  String get deleteInstallmentTitle =>
      locale.languageCode == 'ru' ? 'Удалить рассрочку' : 'Delete Installment';
  String get deleteInstallmentConfirmation => locale.languageCode == 'ru'
      ? 'Вы уверены, что хотите удалить рассрочку?'
      : 'Are you sure you want to delete this installment?';
  String get installmentDeleted =>
      locale.languageCode == 'ru' ? 'Рассрочка удалена' : 'Installment deleted';
  String get installmentsDeleted =>
      locale.languageCode == 'ru' ? 'Рассрочки удалены' : 'Installments deleted';
  String get deleting =>
      locale.languageCode == 'ru' ? 'Удаление...' : 'Deleting...';
  String installmentDeleteError(Object e) =>
      locale.languageCode == 'ru' ? 'Ошибка удаления: $e' : 'Delete error: $e';

  // Settings
  String get language => locale.languageCode == 'ru' ? 'Язык' : 'Language';
  String get updates => locale.languageCode == 'ru' ? 'Обновления' : 'Updates';
  String get checkForUpdates => locale.languageCode == 'ru' ? 'Проверить обновления' : 'Check for updates';
  String get languageRussian => locale.languageCode == 'ru' ? 'Русский' : 'Russian';
  String get languageEnglish => locale.languageCode == 'ru' ? 'English' : 'English';
  String get theme => locale.languageCode == 'ru' ? 'Тема' : 'Theme';
  String get darkTheme =>
      locale.languageCode == 'ru' ? 'Темная тема' : 'Dark Theme';
  String get notifications =>
      locale.languageCode == 'ru' ? 'Уведомления' : 'Notifications';
  String get enableNotifications => locale.languageCode == 'ru'
      ? 'Включить уведомления'
      : 'Enable notifications';
  String get localDatabase =>
      locale.languageCode == 'ru' ? 'Локальная база данных' : 'Local Database';

  // ===== Profile & Authentication =====
  String get profile => locale.languageCode == 'ru' ? 'Профиль' : 'Profile';
  String get editProfile => locale.languageCode == 'ru' ? 'Редактировать профиль' : 'Edit Profile';
  String get logout => locale.languageCode == 'ru' ? 'Выйти' : 'Logout';
  String get profileUpdated => locale.languageCode == 'ru' ? 'Профиль успешно обновлен' : 'Profile updated successfully';
  String get email => locale.languageCode == 'ru' ? 'Email' : 'Email';
  String get enterEmail => locale.languageCode == 'ru' ? 'Введите email' : 'Enter your email';
  String get emailRequired => locale.languageCode == 'ru' ? 'Email обязателен' : 'Email is required';
  String get emailInvalid => locale.languageCode == 'ru' ? 'Введите корректный email' : 'Please enter a valid email';
  String get phone => locale.languageCode == 'ru' ? 'Телефон' : 'Phone';
  String get enterPhone => locale.languageCode == 'ru' ? 'Введите номер телефона' : 'Enter your phone number';
  String get phoneInvalid => locale.languageCode == 'ru' ? 'Введите корректный номер телефона' : 'Please enter a valid phone number';
  String get fullNameRequired => locale.languageCode == 'ru' ? 'Полное имя обязательно' : 'Full name is required';
  String get fullNameTooShort => locale.languageCode == 'ru' ? 'Полное имя должно содержать минимум 2 символа' : 'Full name must be at least 2 characters';
  String get saving => locale.languageCode == 'ru' ? 'Сохранение...' : 'Saving...';
  String get saveChanges => locale.languageCode == 'ru' ? 'Сохранить изменения' : 'Save Changes';

  // ===== Authentication & Registration =====
  String get createAccount => locale.languageCode == 'ru' ? 'Создать аккаунт' : 'Create Account';
  String get signUpToGetStarted => locale.languageCode == 'ru' ? 'Зарегистрируйтесь, чтобы начать' : 'Sign up to get started';
  String get phoneNumber => locale.languageCode == 'ru' ? 'Номер телефона' : 'Phone Number';
  String get enterPhoneNumber => locale.languageCode == 'ru' ? 'Введите номер телефона' : 'Enter your phone number';
  String get phoneRequired => locale.languageCode == 'ru' ? 'Номер телефона обязателен' : 'Phone number is required';
  String get phoneInvalidLength => locale.languageCode == 'ru' ? 'Введите корректный номер телефона' : 'Please enter a valid phone number';
  String get password => locale.languageCode == 'ru' ? 'Пароль' : 'Password';
  String get enterPassword => locale.languageCode == 'ru' ? 'Введите пароль' : 'Enter your password';
  String get passwordRequired => locale.languageCode == 'ru' ? 'Пароль обязателен' : 'Password is required';
  String get passwordTooShort => locale.languageCode == 'ru' ? 'Пароль должен содержать минимум 6 символов' : 'Password must be at least 6 characters';
  String get confirmPassword => locale.languageCode == 'ru' ? 'Подтвердите пароль' : 'Confirm Password';
  String get enterPasswordAgain => locale.languageCode == 'ru' ? 'Введите пароль еще раз' : 'Enter your password again';
  String get confirmPasswordRequired => locale.languageCode == 'ru' ? 'Подтвердите пароль' : 'Please confirm your password';
  String get passwordsDoNotMatch => locale.languageCode == 'ru' ? 'Пароли не совпадают' : 'Passwords do not match';
  String get alreadyHaveAccount => locale.languageCode == 'ru' ? 'Уже есть аккаунт? ' : 'Already have an account? ';
  String get signIn => locale.languageCode == 'ru' ? 'Войти' : 'Sign In';
  String get registrationFailed => locale.languageCode == 'ru' ? 'Ошибка регистрации' : 'Registration failed';
  String get nameRequired => locale.languageCode == 'ru' ? 'Имя обязательно' : 'Name is required';
  String get nameTooShort => locale.languageCode == 'ru' ? 'Имя должно содержать минимум 2 символа' : 'Name must be at least 2 characters';
  String get signInToAccount => locale.languageCode == 'ru' ? 'Войдите в свой аккаунт' : 'Sign in to your account';
  String get enterCredentials => locale.languageCode == 'ru' ? 'Введите данные для входа' : 'Enter your credentials to continue';
  String get loginFailed => locale.languageCode == 'ru' ? 'Ошибка входа' : 'Login failed';
  String get dontHaveAccount => locale.languageCode == 'ru' ? 'Нет аккаунта? ' : "Don't have an account? ";
  String get signUp => locale.languageCode == 'ru' ? 'Зарегистрироваться' : 'Sign Up';

  // Month/term labels
  String get month => locale.languageCode == 'ru' ? 'Месяц' : 'Month';
  String get monthShort => locale.languageCode == 'ru' ? 'мес.' : 'mo.';
  String get monthLabel => locale.languageCode == 'ru' ? 'Месяц' : 'Month';
  String get monthsLabel => locale.languageCode == 'ru' ? 'месяцев' : 'months';

  // Weekdays
  String get dayMon => locale.languageCode == 'ru' ? 'Пн' : 'Mon';
  String get dayTue => locale.languageCode == 'ru' ? 'Вт' : 'Tue';
  String get dayWed => locale.languageCode == 'ru' ? 'Ср' : 'Wed';
  String get dayThu => locale.languageCode == 'ru' ? 'Чт' : 'Thu';
  String get dayFri => locale.languageCode == 'ru' ? 'Пт' : 'Fri';
  String get daySat => locale.languageCode == 'ru' ? 'Сб' : 'Sat';
  String get daySun => locale.languageCode == 'ru' ? 'Вс' : 'Sun';

  String installmentsCount(int count) {
    if (locale.languageCode == 'ru') {
      if (count % 10 == 1 && count % 100 != 11) return '$count рассрочка';
      if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) return '$count рассрочки';
      return '$count рассрочек';
    }
    return '$count installments';
  }

  /// Subtitle for the analytics screen
  String get analyticsSubtitle => locale.languageCode == 'ru' ? 'Обзор ключевых метрик' : 'Overview of key metrics';

  /// A text indicating a value has been copied
  String get copied => locale.languageCode == 'ru' ? 'Скопировано' : 'Copied';

  String daysShort(int days) {
    final suffix = locale.languageCode == 'ru' ? 'д' : 'd';
    return '${days.abs()}$suffix';
  }

  // ===== Analytics =====
  String get totalRevenue => locale.languageCode == 'ru' ? 'Общая выручка' : 'Total Revenue';
  String get newInstallments => locale.languageCode == 'ru' ? 'Новые рассрочки' : 'New Installments';
  String get collectionRate => locale.languageCode == 'ru' ? 'Эффективность' : 'Collection Rate';
  String get portfolioGrowth => locale.languageCode == 'ru' ? 'Рост портфеля' : 'Portfolio Growth';
  String get paymentsThisWeek => locale.languageCode == 'ru' ? 'Выручка за 7 дней' : 'Revenue Last 7 Days';
  String get installmentStatus => locale.languageCode == 'ru' ? 'Статус рассрочек' : 'Installment Status';
  String get activeInstallments => locale.languageCode == 'ru' ? 'Активные рассрочки' : 'Active Installments';
  String get totalPortfolio => locale.languageCode == 'ru' ? 'Общий портфель' : 'Total Portfolio';
  String get totalOverdue => locale.languageCode == 'ru' ? 'Общая просрочка' : 'Total Overdue';
  String get totalInstallmentValue => locale.languageCode == 'ru' ? 'Общий объем бизнеса' : 'Total Business Volume';
  String get averagePerDay => locale.languageCode == 'ru' ? 'В среднем за день' : 'Average per day';
  String get vsPreview28days => locale.languageCode == 'ru' ? 'с предыдущих 28 дней' : 'from previous 28 days';
  String get portfolioDetails => locale.languageCode == 'ru' ? 'Детали портфеля' : 'Portfolio Details';
  String get averageInstallmentValue => locale.languageCode == 'ru' ? 'Средний чек' : 'Average Installment Value';
  String get averageTerm => locale.languageCode == 'ru' ? 'Средний срок' : 'Average Term';
  String get topProduct => locale.languageCode == 'ru' ? 'Самый популярный товар' : 'Top Product';
  String get upcomingRevenue30Days => locale.languageCode == 'ru' ? 'Ожидаемые платежи (30 дней)' : 'Upcoming Revenue (30 days)';
  
  // WhatsApp reminders
  String get sendWhatsAppReminder => locale.languageCode == 'ru' ? 'Отправить напоминание' : 'Send Reminder';
  String get sendReminderConfirmation => locale.languageCode == 'ru' 
      ? 'Вы уверены, что хотите отправить напоминания для выбранных рассрочек?' 
      : 'Are you sure you want to send reminders to the selected installments?';
  String get sendReminderInfo => locale.languageCode == 'ru'
      ? 'Это отправит индивидуальные сообщения каждому клиенту.'
      : 'This will send individual messages to each client.';
  String get sendingWhatsAppReminder => locale.languageCode == 'ru'
      ? 'Отправка напоминания...'
      : 'Sending WhatsApp reminder...';
  String get reminderSent => locale.languageCode == 'ru'
      ? 'Напоминание отправлено'
      : 'Reminder sent';
  String get reminderSentMultiple => locale.languageCode == 'ru'
      ? 'Напоминания отправлены'
      : 'Reminders sent';
  String get partialSuccess => locale.languageCode == 'ru'
      ? 'Частичный успех'
      : 'Partial Success';
  String get remindersSentPartial => locale.languageCode == 'ru'
      ? 'Напоминания отправлены частично'
      : 'Reminders sent partially';
  String get failedReminders => locale.languageCode == 'ru'
      ? 'Неудачные напоминания'
      : 'Failed reminders';
  String get unknownError => locale.languageCode == 'ru'
      ? 'Неизвестная ошибка'
      : 'Unknown error';
  String get ok => locale.languageCode == 'ru'
      ? 'OK'
      : 'OK';
  String get retry => locale.languageCode == 'ru'
      ? 'Повторить'
      : 'Retry';
  String get noInstallmentsSelected => locale.languageCode == 'ru'
      ? 'Не выбрано ни одной рассрочки'
      : 'No installments selected';
  String get noInternetConnection => locale.languageCode == 'ru'
      ? 'Нет подключения к интернету. Пожалуйста, проверьте сеть и попробуйте снова.'
      : 'No internet connection. Please check your network and try again.';
  String get failedToSendReminder => locale.languageCode == 'ru'
      ? 'Не удалось отправить напоминание'
      : 'Failed to send reminder';
  String get failedToSendReminders => locale.languageCode == 'ru'
      ? 'Не удалось отправить напоминания'
      : 'Failed to send reminders';
      
  // WhatsApp integration
  String get whatsAppIntegration => locale.languageCode == 'ru'
      ? 'Интеграция WhatsApp'
      : 'WhatsApp Integration';
  String get whatsAppSetup => locale.languageCode == 'ru'
      ? 'Настройка WhatsApp'
      : 'WhatsApp Setup';
  String get connectWhatsApp => locale.languageCode == 'ru'
      ? 'Подключить WhatsApp для автоматических напоминаний'
      : 'Connect your WhatsApp for automated reminders';
  String get credentials => locale.languageCode == 'ru'
      ? 'Учетные данные'
      : 'Credentials';
  String get templates => locale.languageCode == 'ru'
      ? 'Шаблоны'
      : 'Templates';
  String get setUpWhatsAppIntegration => locale.languageCode == 'ru'
      ? 'Настроить интеграцию WhatsApp'
      : 'Set Up WhatsApp Integration';
  String get changeCredentials => locale.languageCode == 'ru'
      ? 'Изменить учетные данные'
      : 'Change Credentials';
  String get changeTemplates => locale.languageCode == 'ru'
      ? 'Изменить шаблоны'
      : 'Change Templates';
  String get messageTemplates => locale.languageCode == 'ru'
      ? 'Шаблоны сообщений'
      : 'Message Templates';
  String get customizeMessages => locale.languageCode == 'ru'
      ? 'Настройте сообщения напоминаний WhatsApp'
      : 'Customize your WhatsApp reminder messages';
  String get updateCredentials => locale.languageCode == 'ru'
      ? 'Обновить учетные данные'
      : 'Update Credentials';
  String get updateGreenApiCredentials => locale.languageCode == 'ru'
      ? 'Обновите учетные данные Green API'
      : 'Update your Green API credentials';
  String get findCredentialsInfo => locale.languageCode == 'ru'
      ? 'Найдите свои учетные данные на green-api.com в панели управления'
      : 'Find your credentials at green-api.com in your instance dashboard';
  String get howToGetCredentials => locale.languageCode == 'ru'
      ? 'Как получить учетные данные Green API'
      : 'How to get Green API credentials';
  String get credentialsSteps => locale.languageCode == 'ru'
      ? '1. Посетите green-api.com и создайте аккаунт\n'
        '2. Создайте новый Instance в панели управления\n'
        '3. Скопируйте Instance ID и API Token\n'
        '4. Отсканируйте QR-код с помощью WhatsApp'
      : '1. Visit green-api.com and create account\n'
        '2. Create new instance in dashboard\n'
        '3. Copy Instance ID and API Token\n'
        '4. Scan QR code with WhatsApp';
  String get instanceId => locale.languageCode == 'ru'
      ? 'Instance ID'
      : 'Instance ID';
  String get enterInstanceId => locale.languageCode == 'ru'
      ? 'Введите Instance ID Green API'
      : 'Enter your Green API instance ID';
  String get instanceIdRequired => locale.languageCode == 'ru'
      ? 'Instance ID обязателен'
      : 'Instance ID is required';
  String get instanceIdNumeric => locale.languageCode == 'ru'
      ? 'Instance ID должен быть числовым'
      : 'Instance ID must be numeric';
  String get apiToken => locale.languageCode == 'ru'
      ? 'API Token'
      : 'API Token';
  String get enterApiToken => locale.languageCode == 'ru'
      ? 'Введите токен Green API'
      : 'Enter your Green API token';
  String get apiTokenRequired => locale.languageCode == 'ru'
      ? 'API Token обязателен'
      : 'API Token is required';
  String get apiTokenTooShort => locale.languageCode == 'ru'
      ? 'API Token слишком короткий'
      : 'API Token appears to be too short';
  String get testConnection => locale.languageCode == 'ru'
      ? 'Проверить соединение'
      : 'Test Connection';
  String get testing => locale.languageCode == 'ru'
      ? 'Проверка...'
      : 'Testing...';
  String get connectionSuccess => locale.languageCode == 'ru'
      ? 'Соединение успешно! Вы можете продолжить.'
      : 'Connection successful! You can continue.';
  String get connectionFailed => locale.languageCode == 'ru'
      ? 'Соединение не удалось. Проверьте учетные данные.'
      : 'Connection failed. Please check your credentials.';
  String get continue_ => locale.languageCode == 'ru'
      ? 'Продолжить'
      : 'Continue';
  String get completeSetup => locale.languageCode == 'ru'
      ? 'Завершить настройку'
      : 'Complete Setup';
  String get settingUp => locale.languageCode == 'ru'
      ? 'Настройка...'
      : 'Setting up...';
  String get back => locale.languageCode == 'ru'
      ? 'Назад'
      : 'Back';
  String get whatsAppSetupCompleted => locale.languageCode == 'ru'
      ? 'Настройка интеграции WhatsApp завершена!'
      : 'WhatsApp integration setup completed!';
  String get credentialsUpdated => locale.languageCode == 'ru'
      ? 'Учетные данные успешно обновлены!'
      : 'Credentials updated successfully!';
  String get templatesUpdated => locale.languageCode == 'ru'
      ? 'Шаблоны успешно обновлены!'
      : 'Templates updated successfully!';
  String get whatsAppRemindersEnabled => locale.languageCode == 'ru'
      ? 'Напоминания WhatsApp включены'
      : 'WhatsApp reminders enabled';
  String get whatsAppRemindersDisabled => locale.languageCode == 'ru'
      ? 'Напоминания WhatsApp отключены'
      : 'WhatsApp reminders disabled';
  String get failedToUpdateSettings => locale.languageCode == 'ru'
      ? 'Не удалось обновить настройки напоминаний'
      : 'Failed to update reminder settings';
  String get connectionTestFailed => locale.languageCode == 'ru'
      ? 'Проверка соединения не удалась'
      : 'Connection test failed';
  String get testConnectionFirst => locale.languageCode == 'ru'
      ? 'Пожалуйста, сначала проверьте соединение'
      : 'Please test the connection first';
  String get connectionTestRequired => locale.languageCode == 'ru'
      ? 'Для продолжения необходимо успешное соединение'
      : 'Connection test must be successful to continue';
  String get failedToSaveSettings => locale.languageCode == 'ru'
      ? 'Не удалось сохранить настройки'
      : 'Failed to save settings';
  String get failedToSaveTemplates => locale.languageCode == 'ru'
      ? 'Не удалось сохранить шаблоны'
      : 'Failed to save templates';
  String get failedToSaveCredentials => locale.languageCode == 'ru'
      ? 'Не удалось сохранить учетные данные'
      : 'Failed to save credentials';
  String get errorLoadingWhatsAppSettings => locale.languageCode == 'ru'
      ? 'Ошибка загрузки настроек WhatsApp'
      : 'Error loading WhatsApp settings';
  String get errorLoadingUserData => locale.languageCode == 'ru'
      ? 'Ошибка загрузки данных пользователя'
      : 'Error loading user data';
  String get errorDuringLogout => locale.languageCode == 'ru'
      ? 'Ошибка при выходе из системы'
      : 'Error during logout';
  String get unableToLoadProfileInfo => locale.languageCode == 'ru'
      ? 'Не удалось загрузить информацию профиля'
      : 'Unable to load profile information';

  // Updater dialogs (system provided; fallback strings for consistency)
  String get youAreUpToDate => locale.languageCode == 'ru' ? 'У вас последняя версия!' : "You're up to date!";
  String get newestVersionInstalled => locale.languageCode == 'ru' ? 'Установлена самая новая версия приложения.' : 'The newest version is already installed.';
      
  // WhatsApp Template Editor
  String get clientFullName => locale.languageCode == 'ru' ? 'Полное имя клиента' : 'Client\'s full name';
  String get monthlyPaymentAmount => locale.languageCode == 'ru' ? 'Сумма ежемесячного платежа' : 'Monthly payment amount';
  String get paymentDueDate => locale.languageCode == 'ru' ? 'Дата платежа' : 'Payment due date';
  String get daysUntilDueDate => locale.languageCode == 'ru' ? 'Дней до даты платежа' : 'Days until due date';
  String get productServiceName => locale.languageCode == 'ru' ? 'Название товара/услуги' : 'Product/service name';
  String get totalInstallmentPrice => locale.languageCode == 'ru' ? 'Общая стоимость рассрочки' : 'Total installment price';
  String get templateCannotBeEmpty => locale.languageCode == 'ru' ? 'Шаблон не может быть пустым' : 'Template cannot be empty';
  String get templateTooLong => locale.languageCode == 'ru' ? 'Шаблон должен содержать менее 1000 символов' : 'Template must be less than 1000 characters';
  String get invalidVariable => locale.languageCode == 'ru' ? 'Недопустимая переменная' : 'Invalid variable';
  String get unmatchedBraces => locale.languageCode == 'ru' ? 'Несовпадающие скобки в шаблоне' : 'Unmatched braces in template';
  String get considerUsingVariables => locale.languageCode == 'ru' ? 'Рассмотрите использование переменных для персонализации сообщения' : 'Consider using variables to personalize the message';
  String get sevenDaysBefore => locale.languageCode == 'ru' ? 'За 7 дней' : '7 Days Before';
  String get advanceReminder => locale.languageCode == 'ru' ? 'Предварительное напоминание' : 'Advance reminder';
  String get dueToday => locale.languageCode == 'ru' ? 'Сегодня' : 'Due Today';
  String get dueDateReminder => locale.languageCode == 'ru' ? 'Напоминание в день оплаты' : 'Due date reminder';
  String get manual => locale.languageCode == 'ru' ? 'Ручное' : 'Manual';
  String get manualReminder => locale.languageCode == 'ru' ? 'Ручное напоминание' : 'Manual reminder';
  String get sevenDayAdvanceReminder => locale.languageCode == 'ru' ? 'Напоминание за 7 дней' : '7-day advance reminder';
  String get enterMessageTemplate => locale.languageCode == 'ru' ? 'Введите шаблон сообщения здесь...' : 'Enter your message template here...';
  String get preview => locale.languageCode == 'ru' ? 'Предварительный просмотр:' : 'Preview:';
  String get templatePreviewPlaceholder => locale.languageCode == 'ru' ? 'Предварительный просмотр шаблона появится здесь...' : 'Template preview will appear here...';
  String get availableVariables => locale.languageCode == 'ru' ? 'Доступные переменные:' : 'Available Variables:';
  String get templateIssues => locale.languageCode == 'ru' ? 'Проблемы шаблона:' : 'Template Issues:';
  String get hideVariables => locale.languageCode == 'ru' ? 'Спрятать переменные' : 'Hide Variables';
  String get showVariables => locale.languageCode == 'ru' ? 'Показать переменные' : 'Show Variables';

  
  // Selection mode
  String get selectAll => locale.languageCode == 'ru' ? 'Выбрать все' : 'Select All';
  String get selectAllOverdue => locale.languageCode == 'ru' ? 'Выбрать все просроченные' : 'Select All Overdue';
  String get selectionMode => locale.languageCode == 'ru' ? 'Режим выбора' : 'Selection Mode';
  String get selectedItems => locale.languageCode == 'ru' ? 'Выбрано' : 'Selected';
  String get cancelSelection => locale.languageCode == 'ru' ? 'Отменить выбор' : 'Cancel Selection';
  // ===== Subscription System =====
  String get subscriptionWelcomeTitle => locale.languageCode == 'ru' 
      ? 'Добро пожаловать в Instal!' 
      : 'Welcome to Instal!';
  String get subscriptionWelcomeMessage => locale.languageCode == 'ru'
      ? 'Для использования приложения необходима активная подписка. Свяжитесь с нами для получения кода активации.'
      : 'An active subscription is required to use the app. Contact us to get an activation code.';
  String get subscriptionFreeTrialTitle => locale.languageCode == 'ru'
      ? '14-дневная бесплатная пробная версия'
      : '14-Day Free Trial Available';
  String get subscriptionFreeTrialMessage => locale.languageCode == 'ru'
      ? 'Мы предоставляем 14-дневную бесплатную пробную версию с полным доступом ко всем функциям.'
      : 'We offer a 14-day free trial with full access to all features.';
  String get subscriptionExpiredTitle => locale.languageCode == 'ru'
      ? 'Подписка истекла'
      : 'Subscription Expired';
  String get subscriptionExpiredMessage => locale.languageCode == 'ru'
      ? 'Ваша подписка истекла. Свяжитесь с нами для продления доступа к приложению.'
      : 'Your subscription has expired. Contact us to renew your access to the app.';
  String get subscriptionActiveTitle => locale.languageCode == 'ru'
      ? 'Подписка активна'
      : 'Subscription Active';
  String get subscriptionActiveMessage => locale.languageCode == 'ru'
      ? 'У вас есть активная подписка. Наслаждайтесь использованием приложения!'
      : 'You have an active subscription. Enjoy using the app!';
  String get subscriptionContactTitle => locale.languageCode == 'ru'
      ? 'Связаться с нами'
      : 'Contact Us';
  String subscriptionContactMessage(String telegramHandle) => locale.languageCode == 'ru'
      ? 'Свяжитесь с нами в Telegram $telegramHandle для получения кода активации или продления подписки.'
      : 'Contact us on Telegram $telegramHandle to get an activation code or renew your subscription.';
  String subscriptionContactButton(String telegramHandle) => locale.languageCode == 'ru'
      ? 'Связаться $telegramHandle'
      : 'Contact $telegramHandle';
  String subscriptionTelegramCopied(String telegramHandle) => locale.languageCode == 'ru'
      ? 'Telegram $telegramHandle скопирован в буфер обмена'
      : 'Telegram $telegramHandle copied to clipboard';
  String get subscriptionCodeInputTitle => locale.languageCode == 'ru'
      ? 'Активировать код подписки'
      : 'Activate Subscription Code';
  String get subscriptionCodeInputMessage => locale.languageCode == 'ru'
      ? 'Введите код активации, который вы получили от нас.'
      : 'Enter the activation code you received from us.';
  String get subscriptionCodeLabel => locale.languageCode == 'ru'
      ? 'Код активации'
      : 'Activation Code';
  String get subscriptionCodeHint => locale.languageCode == 'ru'
      ? 'SUB-2025-001-ABC123'
      : 'SUB-2025-001-ABC123';
  String get subscriptionCodeRequired => locale.languageCode == 'ru'
      ? 'Введите код активации'
      : 'Please enter an activation code';
  String get subscriptionActivateButton => locale.languageCode == 'ru'
      ? 'Активировать подписку'
      : 'Activate Subscription';
  String get subscriptionValidating => locale.languageCode == 'ru'
      ? 'Проверка кода...'
      : 'Validating code...';
  String get subscriptionActivatedSuccess => locale.languageCode == 'ru'
      ? 'Подписка успешно активирована!'
      : 'Subscription activated successfully!';
  String get subscriptionUserNotFound => locale.languageCode == 'ru'
      ? 'Пользователь не найден. Попробуйте войти заново.'
      : 'User not found. Please try logging in again.';
  String get subscriptionCheckingStatus => locale.languageCode == 'ru'
      ? 'Загрузка...'
      : 'Loading...';
  // Subscription errors
  String get subscriptionErrorUnexpected => locale.languageCode == 'ru'
      ? 'Произошла непредвиденная ошибка. Пожалуйста, попробуйте ещё раз.'
      : 'An unexpected error occurred. Please try again.';
  String get subscriptionErrorNetwork => locale.languageCode == 'ru'
      ? 'Проблема с сетью. Проверьте подключение и повторите попытку.'
      : 'Network problem. Check your connection and try again.';
  String get subscriptionErrorInvalidCode => locale.languageCode == 'ru'
      ? 'Неверный код активации'
      : 'Invalid activation code';
  String get subscriptionErrorCodeUsed => locale.languageCode == 'ru'
      ? 'Этот код уже был использован'
      : 'This code has already been used';
  String get subscriptionErrorCodeExpired => locale.languageCode == 'ru'
      ? 'Срок действия кода истёк'
      : 'The code has expired';
  String get subscriptionErrorCheckFailed => locale.languageCode == 'ru'
      ? 'Не удалось проверить статус подписки. Повторите попытку.'
      : 'Failed to check subscription status. Please try again.';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ru'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
