import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../features/clients/domain/entities/client.dart';
import '../../../../features/wallets/domain/entities/wallet.dart';
import '../../../../features/wallets/domain/entities/wallet_balance.dart';
import '../../../widgets/wallet_selector.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/keyboard_navigable_dropdown.dart';
import '../../../widgets/custom_date_input.dart';

class CreateInstallmentDialogDesktop extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<Client> clients;
  final List<Wallet?> walletOptions;
  final Map<String, WalletBalance> walletBalances;
  final Client? selectedClient;
  final Wallet? selectedWallet;
  final TextEditingController productNameController;
  final TextEditingController cashPriceController;
  final TextEditingController installmentPriceController;
  final TextEditingController termController;
  final TextEditingController downPaymentController;
  final TextEditingController monthlyPaymentController;
  final bool termIncludesDownPayment;
  final FocusNode productNameFocus;
  final FocusNode cashPriceFocus;
  final FocusNode installmentPriceFocus;
  final FocusNode termFocus;
  final FocusNode downPaymentFocus;
  final FocusNode monthlyPaymentFocus;
  final TextEditingController? installmentNumberController;
  final FocusNode? installmentNumberFocus;
  final FocusNode buyingDateFocus;
  final FocusNode installmentStartDateFocus;
  final DateTime? buyingDate;
  final DateTime? installmentStartDate;
  final bool isLoadingData;
  final bool isSaving;
  final int currentStep;
  final void Function(Client?) onClientSelected;
  final void Function(Wallet?) onWalletSelected;
  final VoidCallback onClientDropdownFocus;
  final VoidCallback onWalletDropdownFocus;
  final VoidCallback onProductNameFocus;
  final VoidCallback onCreateClient;
  final VoidCallback onCreateWallet;
  final VoidCallback onSave;
  final ValueChanged<DateTime?> onBuyingDateChanged;
  final ValueChanged<DateTime?> onInstallmentStartDateChanged;
  final ValueChanged<bool> onBuyingDateValidityChanged;
  final ValueChanged<bool> onInstallmentStartDateValidityChanged;
  final GlobalKey<KeyboardNavigableDropdownState<Client>> clientDropdownKey;
  final GlobalKey<KeyboardNavigableDropdownState<Wallet?>> walletDropdownKey;
  final bool isEditMode;
  final bool datesValid;
  const CreateInstallmentDialogDesktop({
    Key? key,
    required this.formKey,
    required this.clients,
    required this.walletOptions,
    required this.walletBalances,
    required this.selectedClient,
    required this.selectedWallet,
    required this.productNameController,
    required this.cashPriceController,
    required this.installmentPriceController,
    required this.termController,
    required this.downPaymentController,
    required this.monthlyPaymentController,
    required this.termIncludesDownPayment,
    required this.productNameFocus,
    required this.cashPriceFocus,
    required this.installmentPriceFocus,
    required this.termFocus,
    required this.downPaymentFocus,
    required this.monthlyPaymentFocus,
    this.installmentNumberController,
    this.installmentNumberFocus,
    required this.buyingDateFocus,
    required this.installmentStartDateFocus,
    required this.buyingDate,
    required this.installmentStartDate,
    required this.isLoadingData,
    required this.isSaving,
    required this.currentStep,
    required this.onClientSelected,
    required this.onWalletSelected,
    required this.onClientDropdownFocus,
    required this.onWalletDropdownFocus,
    required this.onProductNameFocus,
    required this.onCreateClient,
    required this.onCreateWallet,
    required this.onSave,
    required this.onBuyingDateChanged,
    required this.onInstallmentStartDateChanged,
    required this.onBuyingDateValidityChanged,
    required this.onInstallmentStartDateValidityChanged,
    required this.clientDropdownKey,
    required this.walletDropdownKey,
    required this.isEditMode,
    required this.datesValid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    isEditMode 
                        ? (l10n?.editInstallment ?? 'Edit Installment')
                        : (l10n?.addInstallment ?? 'Add Installment'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.subtleBackgroundColor,
                      foregroundColor: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Scrollable Form Content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Client and Investor Selection - side by side on desktop
                      Row(
                        children: [
                          Expanded(child: _buildClientDropdown(context)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildWalletSelector(context)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Installment number (optional, auto when empty) - EDITABLE in edit mode
                      _buildTextField(
                        context: context,
                        controller: installmentNumberController ?? TextEditingController(),
                        focusNode: installmentNumberFocus ?? FocusNode(),
                        nextFocusNode: productNameFocus,
                        label: '${l10n?.installmentNumber ?? 'Installment Number'} (${l10n?.leaveEmptyToAuto ?? 'Пусто'})',
                        keyboardType: TextInputType.number,
                        readOnly: false, // Always editable
                      ),
                      const SizedBox(height: 16),

                      // Product Name - EDITABLE in edit mode
                      _buildTextField(
                        context: context,
                        controller: productNameController,
                        focusNode: productNameFocus,
                        nextFocusNode: cashPriceFocus,
                        label: l10n?.productName ?? 'Product Name',
                        validator: (value) => value?.isEmpty == true ? l10n?.enterProductName ?? 'Enter product name' : null,
                        readOnly: false, // Always editable
                      ),
                      const SizedBox(height: 16),
                      
                      // Prices - side by side on desktop - RESTRICTED in edit mode
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              context: context,
                              controller: cashPriceController,
                              focusNode: cashPriceFocus,
                              nextFocusNode: installmentPriceFocus,
                              label: l10n?.cashPrice ?? 'Cash Price',
                              keyboardType: TextInputType.number,
                              suffix: '₽',
                              validator: (value) => _validateNumber(context, value, l10n?.enterValidPrice ?? 'Enter valid price'),
                              readOnly: isEditMode, // RESTRICTED - financial field
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              context: context,
                              controller: installmentPriceController,
                              focusNode: installmentPriceFocus,
                              nextFocusNode: termFocus,
                              label: l10n?.installmentPrice ?? 'Installment Price',
                              keyboardType: TextInputType.number,
                              suffix: '₽',
                              validator: (value) => _validateNumber(context, value, l10n?.enterValidPrice ?? 'Enter valid price'),
                              readOnly: isEditMode, // RESTRICTED - financial field
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Term and Down Payment - side by side on desktop - RESTRICTED in edit mode
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              context: context,
                              controller: termController,
                              focusNode: termFocus,
                              nextFocusNode: downPaymentFocus,
                              label:
                                  termIncludesDownPayment
                                      ? (l10n?.termMonthsIncludingDownPayment ??
                                          'Term (incl. down payment)')
                                      : (l10n?.termMonthsExcludingDownPayment ??
                                          'Term (payment months)'),
                              keyboardType: TextInputType.number,
                              suffix: l10n?.monthShort ?? 'mo.',
                              validator: (value) => _validateNumber(context, value, l10n?.enterValidTerm ?? 'Enter valid term'),
                              readOnly: isEditMode, // RESTRICTED - financial field
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              context: context,
                              controller: downPaymentController,
                              focusNode: downPaymentFocus,
                              nextFocusNode: buyingDateFocus,
                              label: l10n?.downPaymentFull ?? 'Down Payment',
                              keyboardType: TextInputType.number,
                              suffix: '₽',
                              validator: (value) => _validateNumber(context, value, l10n?.enterValidDownPayment ?? 'Enter valid down payment', allowZero: true),
                              readOnly: isEditMode, // RESTRICTED - financial field
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Monthly Payment (calculated)
                      _buildTextField(
                        context: context,
                        controller: monthlyPaymentController,
                        focusNode: monthlyPaymentFocus,
                        nextFocusNode: buyingDateFocus,
                        label: l10n?.monthlyPayment ?? 'Monthly Payment',
                        keyboardType: TextInputType.number,
                        suffix: '₽',
                        readOnly: isEditMode,
                        validator: (value) => _validateNumber(context, value, l10n?.validateMonthlyPayment ?? 'Monthly payment must be greater than 0'),
                      ),
                      const SizedBox(height: 16),
                      
                      // Dates - side by side on desktop - RESTRICTED in edit mode
                      Row(
                        children: [
                          Expanded(
                        child: CustomDateInput(
                          label: l10n?.buyingDate ?? 'Buying Date',
                          value: buyingDate,
                          onChanged: onBuyingDateChanged,
                          onValidityChanged: onBuyingDateValidityChanged,
                          focusNode: buyingDateFocus,
                          nextFocusNode: installmentStartDateFocus,
                          enabled: !isEditMode, // RESTRICTED - date field
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          locale: l10n?.locale,
                        ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                        child: CustomDateInput(
                          label: l10n?.installmentStartDate ?? 'Installment Start Date',
                          value: installmentStartDate,
                          onChanged: onInstallmentStartDateChanged,
                          onValidityChanged: onInstallmentStartDateValidityChanged,
                          focusNode: installmentStartDateFocus,
                          textInputAction: TextInputAction.done,
                          onSubmitted: onSave,
                          enabled: !isEditMode, // RESTRICTED - date field
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          locale: l10n?.locale,
                        ),
                          ),
                        ],
                      ),
                      // removed old placement of installment number
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Actions - Row at the end for desktop
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      l10n?.cancel ?? 'Cancel',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CustomButton(
                    text: l10n?.save ?? 'Save',
                    onPressed: (isSaving || !datesValid) ? null : onSave,
                    showIcon: false,
                    width: 120,
                    height: 40,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientDropdown(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    if (isLoadingData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.client ?? 'Client',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.subtleBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n?.loadingClients ?? 'Загрузка клиентов...',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return KeyboardNavigableDropdown<Client>(
      key: clientDropdownKey,
      value: selectedClient,
      items: clients,
      getDisplayText: (client) => client.fullName,
      getSearchText: (client) => client.fullName,
      onChanged: onClientSelected,
      onNext: onWalletDropdownFocus,
      label: l10n.client ?? 'Client',
      hint: '${l10n.search ?? 'Search'}...',
      noItemsMessage: l10n.noClientsFound,
      onCreateNew: onCreateClient,
      autoFocus: currentStep == 0 && !isLoadingData,
    );
  }

  Widget _buildWalletSelector(BuildContext context) {
    return WalletSelector(
      wallets: walletOptions.where((w) => w != null).cast<Wallet>().toList(),
      walletBalances: walletBalances,
      selectedWallet: selectedWallet,
      isLoading: isLoadingData,
      onWalletSelected: (wallet) {
        onWalletSelected(wallet);
      },
      onCreateWallet: onCreateWallet,
      dropdownKey: walletDropdownKey,
      nextFocusNode: installmentNumberFocus,
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
    required String label,
    TextInputType? keyboardType,
    String? suffix,
    String? Function(String?)? validator,
    bool readOnly = false,
    bool isLast = false,
    VoidCallback? onSubmit,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      readOnly: readOnly,
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: (_) {
        if (isLast) {
          onSubmit?.call();
        } else if (nextFocusNode != null) {
          nextFocusNode.requestFocus();
        }
      },
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: readOnly ? AppTheme.textSecondary : AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        suffixText: suffix,
        suffixStyle: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: readOnly ? AppTheme.subtleBackgroundColor : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: validator,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : null,
    );
  }

  String? _validateNumber(BuildContext context, String? value, String message, {bool allowZero = false}) {
    if (value?.isEmpty == true) return message;
    final number = double.tryParse(value!);
    if (number == null) return message;
    if (!allowZero && number <= 0) return message;
    if (allowZero && number < 0) return message;
    return null;
  }
} 
