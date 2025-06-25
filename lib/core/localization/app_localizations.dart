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
      locale.languageCode == 'ru' ? 'Контактный номер' : 'Contact Number';
  String get passportNumber =>
      locale.languageCode == 'ru' ? 'Номер паспорта' : 'Passport Number';
  String get address => locale.languageCode == 'ru' ? 'Адрес' : 'Address';

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
  String get downPayment =>
      locale.languageCode == 'ru' ? 'Первоначальный взнос' : 'Down Payment';
  String get downPaymentShort => locale.languageCode == 'ru' ? 'Взнос' : 'Down';
  String get downPaymentFull =>
      locale.languageCode == 'ru' ? 'Первоначальный взнос' : 'Down Payment';
  String get monthlyPayment =>
      locale.languageCode == 'ru' ? 'Ежемесячный платеж' : 'Monthly Payment';
  String get buyingDate =>
      locale.languageCode == 'ru' ? 'Дата покупки' : 'Buying Date';
  String get installmentStartDate => locale.languageCode == 'ru'
      ? 'Дата начала рассрочки'
      : 'Installment Start Date';
  String get installmentEndDate => locale.languageCode == 'ru'
      ? 'Дата окончания рассрочки'
      : 'Installment End Date';
  String get paidAmount => locale.languageCode == 'ru' ? 'Оплачено' : 'Paid Amount';
  String get leftAmount => locale.languageCode == 'ru' ? 'Осталось' : 'Amount Left';
  String get dueDate => locale.languageCode == 'ru' ? 'Срок оплаты' : 'Due Date';
  String get nextPayment =>
      locale.languageCode == 'ru' ? 'Следующий платеж' : 'Next Payment';

  // ===== Statuses =====
  String get paid => locale.languageCode == 'ru' ? 'Оплачено' : 'Paid';
  String get upcoming =>
      locale.languageCode == 'ru' ? 'Предстоящий' : 'Upcoming';
  String get dueToPay => locale.languageCode == 'ru' ? 'К оплате' : 'Due to Pay';
  String get overdue => locale.languageCode == 'ru' ? 'Просрочено' : 'Overdue';

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
  String installmentDeleteError(Object e) =>
      locale.languageCode == 'ru' ? 'Ошибка удаления: $e' : 'Delete error: $e';

  // Settings
  String get language => locale.languageCode == 'ru' ? 'Язык' : 'Language';
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

  // Month/term labels
  String get month => locale.languageCode == 'ru' ? 'Месяц' : 'Month';
  String get months => locale.languageCode == 'ru' ? 'месяцев' : 'months';
  String get monthShort => locale.languageCode == 'ru' ? 'мес.' : 'mo.';
  String get monthLabel => locale.languageCode == 'ru' ? 'Месяц' : 'Month';
  String get monthsLabel => locale.languageCode == 'ru' ? 'месяцев' : 'months';

  // ===== Analytics Screen =====
  String get totalPortfolio => locale.languageCode == 'ru' ? 'Общий портфель' : 'Total Portfolio';
  String get totalReceived => locale.languageCode == 'ru' ? 'Всего получено' : 'Total Received';
  String get totalOutstanding => locale.languageCode == 'ru' ? 'Остаток долга' : 'Total Outstanding';
  String get activeInstallments => locale.languageCode == 'ru' ? 'Активные рассрочки' : 'Active Installments';
  String get completedInstallments => locale.languageCode == 'ru' ? 'Завершенные рассрочки' : 'Completed Installments';
  String get overdueInstallments => locale.languageCode == 'ru' ? 'Просроченные рассрочки' : 'Overdue Installments';
  String get installmentStatus => locale.languageCode == 'ru' ? 'Статус рассрочек' : 'Installment Status';
  String get productPopularity => locale.languageCode == 'ru' ? 'Популярность товаров' : 'Product Popularity';

  String get totalSales => locale.languageCode == 'ru' ? 'Общие продажи' : 'Total Sales';
  String get lastWeek => locale.languageCode == 'ru' ? 'Прошлая неделя' : 'Last Week';
  String get lastMonth => locale.languageCode == 'ru' ? 'Прошлый месяц' : 'Last Month';
  
  String get keyMetrics => locale.languageCode == 'ru' ? 'Ключевые метрики' : 'Key Metrics';

  String get totalRevenue => locale.languageCode == 'ru' ? 'Общая выручка' : 'Total Revenue';
  String get totalVisitors => locale.languageCode == 'ru' ? 'Всего посетителей' : 'Total Visitors';
  String get totalTransactions => locale.languageCode == 'ru' ? 'Всего транзакций' : 'Total Transactions';
  String get totalProducts => locale.languageCode == 'ru' ? 'Всего товаров' : 'Total Products';
  String get vsPreview28days => locale.languageCode == 'ru' ? ' за предыдущие 28 дней' : ' vs previous 28 days';

  String get averageInstallmentAmount => locale.languageCode == 'ru' ? 'Средняя сумма рассрочки' : 'Average Installment Amount';
  String get averageOverdueDays => locale.languageCode == 'ru' ? 'Средний срок просрочки' : 'Average Overdue Days';
  String get mostCommonProduct => locale.languageCode == 'ru' ? 'Самый частый товар' : 'Most Common Product';
  String get highestRiskClient => locale.languageCode == 'ru' ? 'Самый рискованный клиент' : 'Highest Risk Client';

  String get pending => locale.languageCode == 'ru' ? 'В ожидании' : 'Pending';
  String get canceled => locale.languageCode == 'ru' ? 'Отменено' : 'Canceled';
  
  String get paymentsThisWeek => locale.languageCode == 'ru' ? 'Платежи за неделю' : 'Payments This Week';
  String get averagePerDay => locale.languageCode == 'ru' ? 'В среднем за день' : 'Average per day';
  String get comparedToLastWeek => locale.languageCode == 'ru' ? 'с прошлой недели' : 'vs last week';

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
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['ru', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}