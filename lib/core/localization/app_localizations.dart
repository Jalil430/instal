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

  // Navigation
  String get installments => locale.languageCode == 'ru' ? 'Рассрочки' : 'Installments';
  String get client => locale.languageCode == 'ru' ? 'Клиент' : 'Client';
  String get clients => locale.languageCode == 'ru' ? 'Клиенты' : 'Clients';
  String get investors => locale.languageCode == 'ru' ? 'Инвесторы' : 'Investors';
  
  // Common
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
  String get month => locale.languageCode == 'ru' ? 'Месяц' : 'Month';
  String get months => locale.languageCode == 'ru' ? 'месяцев' : 'months';
  
  // Installment fields
  String get productName => locale.languageCode == 'ru' ? 'Название товара' : 'Product Name';
  String get cashPrice => locale.languageCode == 'ru' ? 'Цена за наличные' : 'Cash Price';
  String get installmentPrice => locale.languageCode == 'ru' ? 'Цена в рассрочку' : 'Installment Price';
  String get term => locale.languageCode == 'ru' ? 'Срок (месяцы)' : 'Term (Months)';
  String get downPayment => locale.languageCode == 'ru' ? 'Первоначальный взнос' : 'Down Payment';
  String get downPaymentShort => locale.languageCode == 'ru' ? 'Взнос' : 'Down';
  String get monthlyPayment => locale.languageCode == 'ru' ? 'Ежемесячный платеж' : 'Monthly Payment';
  String get buyingDate => locale.languageCode == 'ru' ? 'Дата покупки' : 'Buying Date';
  String get installmentStartDate => locale.languageCode == 'ru' ? 'Дата начала рассрочки' : 'Installment Start Date';
  String get installmentEndDate => locale.languageCode == 'ru' ? 'Дата окончания рассрочки' : 'Installment End Date';
  String get paidAmount => locale.languageCode == 'ru' ? 'Оплачено' : 'Paid';
  String get leftAmount => locale.languageCode == 'ru' ? 'Осталось' : 'Left';
  String get dueDate => locale.languageCode == 'ru' ? 'Срок оплаты' : 'Due Date';
  String get nextPayment => locale.languageCode == 'ru' ? 'Следующий платеж' : 'Next Payment';
  
  // Client fields
  String get fullName => locale.languageCode == 'ru' ? 'Полное имя' : 'Full Name';
  String get contactNumber => locale.languageCode == 'ru' ? 'Контактный номер' : 'Contact Number';
  String get passportNumber => locale.languageCode == 'ru' ? 'Номер паспорта' : 'Passport Number';
  String get address => locale.languageCode == 'ru' ? 'Адрес' : 'Address';
  
  // Investor fields
  String get investmentAmount => locale.languageCode == 'ru' ? 'Сумма инвестиций' : 'Investment Amount';
  String get investorPercentage => locale.languageCode == 'ru' ? 'Процент инвестора' : 'Investor Percentage';
  String get userPercentage => locale.languageCode == 'ru' ? 'Процент пользователя' : 'User Percentage';
  
  // Status values
  String get paid => locale.languageCode == 'ru' ? 'Оплачено' : 'Paid';
  String get upcoming => locale.languageCode == 'ru' ? 'Предстоящий' : 'Upcoming';
  String get dueToPay => locale.languageCode == 'ru' ? 'К оплате' : 'Due to Pay';
  String get overdue => locale.languageCode == 'ru' ? 'Просрочено' : 'Overdue';
  
  // Actions
  String get addInstallment => locale.languageCode == 'ru' ? 'Добавить рассрочку' : 'Add Installment';
  String get addClient => locale.languageCode == 'ru' ? 'Добавить клиента' : 'Add Client';
  String get addInvestor => locale.languageCode == 'ru' ? 'Добавить инвестора' : 'Add Investor';
  String get editInstallment => locale.languageCode == 'ru' ? 'Редактировать рассрочку' : 'Edit Installment';
  String get editClient => locale.languageCode == 'ru' ? 'Редактировать клиента' : 'Edit Client';
  String get editInvestor => locale.languageCode == 'ru' ? 'Редактировать инвестора' : 'Edit Investor';
  String get registerPayment => locale.languageCode == 'ru' ? 'Зарегистрировать платеж' : 'Register Payment';
  String get confirm => locale.languageCode == 'ru' ? 'Подтвердить' : 'Confirm';
  String get cancelPayment => locale.languageCode == 'ru' ? 'Отменить' : 'Cancel Payment';
  
  // Sort options
  String get sortBy => locale.languageCode == 'ru' ? 'Сортировать по' : 'Sort by';
  String get creationDate => locale.languageCode == 'ru' ? 'Дата создания' : 'Creation Date';
  
  // Validation messages
  String get fieldRequired => locale.languageCode == 'ru' ? 'Это поле обязательно' : 'This field is required';
  String get invalidNumber => locale.languageCode == 'ru' ? 'Неверный номер' : 'Invalid number';
  String get invalidAmount => locale.languageCode == 'ru' ? 'Неверная сумма' : 'Invalid amount';
  
  // Dialog messages
  String get cancelPaymentQuestion => locale.languageCode == 'ru' ? 'Отменить оплату этого платежа?' : 'Cancel payment for this installment?';

  // Delete confirmations
  String deleteInvestorConfirmation(String name) => locale.languageCode == 'ru'
      ? 'Вы уверены, что хотите удалить инвестора "$name"?'
      : 'Are you sure you want to delete investor "$name"?';
  String get deleteInvestorTitle => locale.languageCode == 'ru' ? 'Удалить инвестора' : 'Delete Investor';
  String get investorDeleted => locale.languageCode == 'ru' ? 'Инвестор удален' : 'Investor deleted';
  String investorDeleteError(Object e) => locale.languageCode == 'ru'
      ? 'Ошибка удаления: $e'
      : 'Delete error: $e';

  String deleteClientConfirmation(String name) => locale.languageCode == 'ru'
      ? 'Вы уверены, что хотите удалить клиента "$name"?'
      : 'Are you sure you want to delete client "$name"?';
  String get deleteClientTitle => locale.languageCode == 'ru' ? 'Удалить клиента' : 'Delete Client';
  String get clientDeleted => locale.languageCode == 'ru' ? 'Клиент удален' : 'Client deleted';
  String clientDeleteError(Object e) => locale.languageCode == 'ru'
      ? 'Ошибка удаления: $e'
      : 'Delete error: $e';

  // Table headers and section headers
  String get fullNameHeader => locale.languageCode == 'ru' ? 'ПОЛНОЕ ИМЯ' : 'FULL NAME';
  String get investmentAmountHeader => locale.languageCode == 'ru' ? 'СУММА ИНВЕСТИЦИИ' : 'INVESTMENT AMOUNT';
  String get investorShareHeader => locale.languageCode == 'ru' ? 'ДОЛЯ ИНВЕСТОРА' : 'INVESTOR SHARE';
  String get userShareHeader => locale.languageCode == 'ru' ? 'ДОЛЯ ПОЛЬЗОВАТЕЛЯ' : 'USER SHARE';
  String get creationDateHeader => locale.languageCode == 'ru' ? 'ДАТА СОЗДАНИЯ' : 'CREATION DATE';
  String get contactNumberHeader => locale.languageCode == 'ru' ? 'КОНТАКТНЫЙ НОМЕР' : 'CONTACT NUMBER';
  String get passportNumberHeader => locale.languageCode == 'ru' ? 'НОМЕР ПАСПОРТА' : 'PASSPORT NUMBER';
  String get addressHeader => locale.languageCode == 'ru' ? 'АДРЕС' : 'ADDRESS';
  String get productNameHeader => locale.languageCode == 'ru' ? 'ТОВАР' : 'PRODUCT';
  String get amountHeader => locale.languageCode == 'ru' ? 'СУММА' : 'AMOUNT';
  String get termHeader => locale.languageCode == 'ru' ? 'СРОК' : 'TERM';
  String get buyingDateHeader => locale.languageCode == 'ru' ? 'ДАТА ПОКУПКИ' : 'BUYING DATE';
  String get scheduleHeader => locale.languageCode == 'ru' ? 'График платежей' : 'Payment Schedule';
  String get financialInfoHeader => locale.languageCode == 'ru' ? 'Финансовая информация' : 'Financial Information';
  String get datesHeader => locale.languageCode == 'ru' ? 'Сроки и даты' : 'Dates';
  String get noPayments => locale.languageCode == 'ru' ? 'Нет платежей' : 'No payments';
  String get noClientsAvailable => locale.languageCode == 'ru' ? 'Нет доступных клиентов' : 'No clients available';
  String get empty => locale.languageCode == 'ru' ? 'Пусто' : 'Empty';
  String get selectClient => locale.languageCode == 'ru' ? 'Выберите клиента' : 'Select a client';
  String get investorOptional => locale.languageCode == 'ru' ? 'Инвестор (необязательно)' : 'Investor (optional)';
  String get notFound => locale.languageCode == 'ru' ? 'Ничего не найдено' : 'Nothing found';
  String get nextPaymentHeader => locale.languageCode == 'ru' ? 'СЛЕДУЮЩИЙ ПЛАТЕЖ' : 'NEXT PAYMENT';
  String get paymentHeader => locale.languageCode == 'ru' ? 'ПЛАТЕЖ' : 'PAYMENT';
  String get statusHeader => locale.languageCode == 'ru' ? 'СТАТУС' : 'STATUS';

  // Dialogs and validation
  String get deleteInstallmentTitle => locale.languageCode == 'ru' ? 'Удалить рассрочку' : 'Delete Installment';
  String get deleteInstallmentConfirmation => locale.languageCode == 'ru' ? 'Вы уверены, что хотите удалить рассрочку?' : 'Are you sure you want to delete this installment?';
  String get installmentDeleted => locale.languageCode == 'ru' ? 'Рассрочка удалена' : 'Installment deleted';
  String installmentDeleteError(Object e) => locale.languageCode == 'ru' ? 'Ошибка удаления: $e' : 'Delete error: $e';

  // Validation
  String get enterProductName => locale.languageCode == 'ru' ? 'Введите название товара' : 'Enter product name';
  String get enterValidPrice => locale.languageCode == 'ru' ? 'Введите корректную цену' : 'Enter a valid price';
  String get enterValidTerm => locale.languageCode == 'ru' ? 'Введите срок в месяцах' : 'Enter a valid term in months';
  String get enterValidDownPayment => locale.languageCode == 'ru' ? 'Введите сумму первоначального взноса' : 'Enter a valid down payment amount';
  String get enterValidMonthlyPayment => locale.languageCode == 'ru' ? 'Ежемесячный платеж должен быть больше 0' : 'Monthly payment must be greater than 0';

  // Settings and navigation
  String get settings => locale.languageCode == 'ru' ? 'Настройки' : 'Settings';
  String get language => locale.languageCode == 'ru' ? 'Язык' : 'Language';
  String get theme => locale.languageCode == 'ru' ? 'Тема' : 'Theme';
  String get darkTheme => locale.languageCode == 'ru' ? 'Темная тема' : 'Dark Theme';
  String get notifications => locale.languageCode == 'ru' ? 'Уведомления' : 'Notifications';
  String get enableNotifications => locale.languageCode == 'ru' ? 'Включить уведомления' : 'Enable notifications';

  // Month/term labels
  String get monthShort => locale.languageCode == 'ru' ? 'мес.' : 'mo.';
  String get monthLabel => locale.languageCode == 'ru' ? 'Месяц' : 'Month';
  String get monthsLabel => locale.languageCode == 'ru' ? 'месяцев' : 'months';
  String get downPaymentLabel => locale.languageCode == 'ru' ? 'Взнос' : 'Down';
  String get downPaymentFull => locale.languageCode == 'ru' ? 'Первоначальный взнос' : 'Down Payment';

  // Context menu actions
  String get select => locale.languageCode == 'ru' ? 'Выбрать' : 'Select';
  String get deleteAction => locale.languageCode == 'ru' ? 'Удалить' : 'Delete';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
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