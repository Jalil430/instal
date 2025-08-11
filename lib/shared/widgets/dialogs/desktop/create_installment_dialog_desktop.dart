import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../features/clients/domain/entities/client.dart';
import '../../../../features/investors/domain/entities/investor.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/keyboard_navigable_dropdown.dart';

class CreateInstallmentDialogDesktop extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<Client> clients;
  final List<Investor?> investorOptions;
  final Client? selectedClient;
  final Investor? selectedInvestor;
  final TextEditingController productNameController;
  final TextEditingController cashPriceController;
  final TextEditingController installmentPriceController;
  final TextEditingController termController;
  final TextEditingController downPaymentController;
  final TextEditingController monthlyPaymentController;
  final FocusNode productNameFocus;
  final FocusNode cashPriceFocus;
  final FocusNode installmentPriceFocus;
  final FocusNode termFocus;
  final FocusNode downPaymentFocus;
  final FocusNode monthlyPaymentFocus;
  final TextEditingController? installmentNumberController;
  final FocusNode? installmentNumberFocus;
  final DateTime? buyingDate;
  final DateTime? installmentStartDate;
  final bool isLoadingData;
  final bool isSaving;
  final int currentStep;
  final void Function(Client?) onClientSelected;
  final void Function(Investor?) onInvestorSelected;
  final VoidCallback onClientDropdownFocus;
  final VoidCallback onInvestorDropdownFocus;
  final VoidCallback onProductNameFocus;
  final VoidCallback onCreateClient;
  final VoidCallback onCreateInvestor;
  final VoidCallback onSave;
  final Function(DateTime) onBuyingDateChanged;
  final Function(DateTime) onInstallmentStartDateChanged;
  final GlobalKey<KeyboardNavigableDropdownState<Client>> clientDropdownKey;
  final GlobalKey<KeyboardNavigableDropdownState<Investor?>> investorDropdownKey;
  
  const CreateInstallmentDialogDesktop({
    Key? key,
    required this.formKey,
    required this.clients,
    required this.investorOptions,
    required this.selectedClient,
    required this.selectedInvestor,
    required this.productNameController,
    required this.cashPriceController,
    required this.installmentPriceController,
    required this.termController,
    required this.downPaymentController,
    required this.monthlyPaymentController,
    required this.productNameFocus,
    required this.cashPriceFocus,
    required this.installmentPriceFocus,
    required this.termFocus,
    required this.downPaymentFocus,
    required this.monthlyPaymentFocus,
    this.installmentNumberController,
    this.installmentNumberFocus,
    required this.buyingDate,
    required this.installmentStartDate,
    required this.isLoadingData,
    required this.isSaving,
    required this.currentStep,
    required this.onClientSelected,
    required this.onInvestorSelected,
    required this.onClientDropdownFocus,
    required this.onInvestorDropdownFocus,
    required this.onProductNameFocus,
    required this.onCreateClient,
    required this.onCreateInvestor,
    required this.onSave,
    required this.onBuyingDateChanged,
    required this.onInstallmentStartDateChanged,
    required this.clientDropdownKey,
    required this.investorDropdownKey,
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
                    l10n?.addInstallment ?? 'Add Installment',
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
                          Expanded(child: _buildInvestorDropdown(context)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Installment number (optional, auto when empty)
                      _buildTextField(
                        context: context,
                        controller: installmentNumberController ?? TextEditingController(),
                        focusNode: installmentNumberFocus ?? FocusNode(),
                        nextFocusNode: productNameFocus,
                        label: '${l10n?.installmentNumber ?? 'Installment Number'} (${l10n?.leaveEmptyToAuto ?? 'Пусто'})',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      // Product Name
                      _buildTextField(
                        context: context,
                        controller: productNameController,
                        focusNode: productNameFocus,
                        nextFocusNode: cashPriceFocus,
                        label: l10n?.productName ?? 'Product Name',
                        validator: (value) => value?.isEmpty == true ? l10n?.enterProductName ?? 'Enter product name' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Prices - side by side on desktop
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
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Term and Down Payment - side by side on desktop
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              context: context,
                              controller: termController,
                              focusNode: termFocus,
                              nextFocusNode: downPaymentFocus,
                              label: l10n?.term ?? 'Term (months)',
                              keyboardType: TextInputType.number,
                              suffix: l10n?.monthShort ?? 'mo.',
                              validator: (value) => _validateNumber(context, value, l10n?.enterValidTerm ?? 'Enter valid term'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              context: context,
                              controller: downPaymentController,
                              focusNode: downPaymentFocus,
                              label: l10n?.downPaymentFull ?? 'Down Payment',
                              keyboardType: TextInputType.number,
                              suffix: '₽',
                              validator: (value) => _validateNumber(context, value, l10n?.enterValidDownPayment ?? 'Enter valid down payment', allowZero: true),
                              isLast: true,
                              onSubmit: onSave,
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
                        label: l10n?.monthlyPayment ?? 'Monthly Payment',
                        keyboardType: TextInputType.number,
                        suffix: '₽',
                        readOnly: true,
                        validator: (value) => _validateNumber(context, value, l10n?.validateMonthlyPayment ?? 'Monthly payment must be greater than 0'),
                      ),
                      const SizedBox(height: 16),
                      
                      // Dates - side by side on desktop
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              context: context,
                              label: l10n?.buyingDate ?? 'Buying Date',
                              value: buyingDate,
                              onChanged: onBuyingDateChanged,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDateField(
                              context: context,
                              label: l10n?.installmentStartDate ?? 'Installment Start Date',
                              value: installmentStartDate,
                              onChanged: onInstallmentStartDateChanged,
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
                    onPressed: isSaving ? null : onSave,
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
                  'Loading clients...',
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
      onNext: onInvestorDropdownFocus,
      label: l10n.client ?? 'Client',
      hint: '${l10n.search ?? 'Search'}...',
      noItemsMessage: 'No clients found',
      onCreateNew: onCreateClient,
      autoFocus: currentStep == 0 && !isLoadingData,
    );
  }

  Widget _buildInvestorDropdown(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    if (isLoadingData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.investorOptional ?? 'Investor (Optional)',
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
                  'Loading investors...',
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

    return KeyboardNavigableDropdown<Investor?>(
      key: investorDropdownKey,
      value: selectedInvestor,
      items: investorOptions,
      getDisplayText: (investor) => investor?.fullName ?? (l10n.withoutInvestor ?? 'Without Investor'),
      getSearchText: (investor) => investor?.fullName ?? (l10n.withoutInvestor ?? 'Without Investor'),
      onChanged: onInvestorSelected,
      onNext: () {
        // After choosing investor, move focus to installment number
        installmentNumberFocus?.requestFocus();
      },
      label: l10n.investorOptional ?? 'Investor (Optional)',
      hint: '${l10n.search ?? 'Search'}...',
      noItemsMessage: 'No investors found',
      onCreateNew: onCreateInvestor,
      autoFocus: currentStep == 1 && !isLoadingData,
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

  Widget _buildDateField({
    required BuildContext context,
    required String label,
    required DateTime? value,
    required Function(DateTime) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (date != null) {
              onChanged(date);
            }
          },
          child: Container(
            width: double.infinity,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value != null
                        ? '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}'
                        : AppLocalizations.of(context)?.selectDate ?? 'Select date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: value != null ? AppTheme.textPrimary : AppTheme.textHint,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  color: AppTheme.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
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