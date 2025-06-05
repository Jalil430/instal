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
  
  // Sort options
  String get sortBy => locale.languageCode == 'ru' ? 'Сортировать по' : 'Sort by';
  String get creationDate => locale.languageCode == 'ru' ? 'Дате создания' : 'Creation Date';
  
  // Validation messages
  String get fieldRequired => locale.languageCode == 'ru' ? 'Это поле обязательно' : 'This field is required';
  String get invalidNumber => locale.languageCode == 'ru' ? 'Неверный номер' : 'Invalid number';
  String get invalidAmount => locale.languageCode == 'ru' ? 'Неверная сумма' : 'Invalid amount';
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