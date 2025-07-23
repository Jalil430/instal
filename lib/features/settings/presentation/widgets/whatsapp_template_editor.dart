import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/custom_text_field.dart';

class WhatsAppTemplateEditor extends StatefulWidget {
  final TextEditingController template7DaysController;
  final TextEditingController templateDueTodayController;
  final TextEditingController templateManualController;

  const WhatsAppTemplateEditor({
    super.key,
    required this.template7DaysController,
    required this.templateDueTodayController,
    required this.templateManualController,
  });

  @override
  State<WhatsAppTemplateEditor> createState() => _WhatsAppTemplateEditorState();
}

class _WhatsAppTemplateEditorState extends State<WhatsAppTemplateEditor> {
  int _selectedTabIndex = 0;
  List<String> _validationErrors = [];
  
  final List<String> _availableVariables = [
    '{client_name}',
    '{installment_amount}',
    '{due_date}',
    '{days_remaining}',
    '{product_name}',
    '{total_amount}',
  ];
  
  Map<String, String> _getVariableDescriptions(BuildContext context) => {
    '{client_name}': AppLocalizations.of(context)?.clientFullName ?? 'Client\'s full name',
    '{installment_amount}': AppLocalizations.of(context)?.monthlyPaymentAmount ?? 'Monthly payment amount',
    '{due_date}': AppLocalizations.of(context)?.paymentDueDate ?? 'Payment due date',
    '{days_remaining}': AppLocalizations.of(context)?.daysUntilDueDate ?? 'Days until due date',
    '{product_name}': AppLocalizations.of(context)?.productServiceName ?? 'Product/service name',
    '{total_amount}': AppLocalizations.of(context)?.totalInstallmentPrice ?? 'Total installment price',
  };

  @override
  void initState() {
    super.initState();
    // Add listeners to validate templates in real-time
    widget.template7DaysController.addListener(_validateCurrentTemplate);
    widget.templateDueTodayController.addListener(_validateCurrentTemplate);
    widget.templateManualController.addListener(_validateCurrentTemplate);
  }

  @override
  void dispose() {
    widget.template7DaysController.removeListener(_validateCurrentTemplate);
    widget.templateDueTodayController.removeListener(_validateCurrentTemplate);
    widget.templateManualController.removeListener(_validateCurrentTemplate);
    super.dispose();
  }

  void _validateCurrentTemplate() {
    setState(() {
      _validationErrors = _validateTemplate(_getCurrentController().text, context);
    });
  }

  TextEditingController _getCurrentController() {
    switch (_selectedTabIndex) {
      case 0:
        return widget.template7DaysController;
      case 1:
        return widget.templateDueTodayController;
      case 2:
        return widget.templateManualController;
      default:
        return widget.templateManualController;
    }
  }

  List<String> _validateTemplate(String template, BuildContext context) {
    List<String> errors = [];
    
    if (template.trim().isEmpty) {
      errors.add(AppLocalizations.of(context)?.templateCannotBeEmpty ?? 'Template cannot be empty');
      return errors;
    }
    
    if (template.length > 1000) {
      errors.add(AppLocalizations.of(context)?.templateTooLong ?? 'Template must be less than 1000 characters');
    }
    
    // Check for invalid variable syntax
    RegExp variablePattern = RegExp(r'\{[^}]*\}');
    Iterable<Match> matches = variablePattern.allMatches(template);
    
    for (Match match in matches) {
      String variable = match.group(0)!;
      if (!_availableVariables.contains(variable)) {
        errors.add('${AppLocalizations.of(context)?.invalidVariable ?? 'Invalid variable'}: $variable');
      }
    }
    
    // Check for unclosed braces
    int openBraces = template.split('{').length - 1;
    int closeBraces = template.split('}').length - 1;
    if (openBraces != closeBraces) {
      errors.add(AppLocalizations.of(context)?.unmatchedBraces ?? 'Unmatched braces in template');
    }
    
    // Warn if no variables are used
    bool hasVariables = _availableVariables.any((variable) => template.contains(variable));
    if (!hasVariables) {
      errors.add(AppLocalizations.of(context)?.considerUsingVariables ?? 'Consider using variables to personalize the message');
    }
    
    return errors;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab selector
          _buildTabSelector(),
          const SizedBox(height: 16),
          
          // Template editor
          _buildTemplateEditor(),
          const SizedBox(height: 16),
          
          // Available variables
          _buildVariablesHelper(),
        ],
      ),
    );
  }
  
  Widget _buildTabSelector() {
    final tabs = [
      {
        'title': AppLocalizations.of(context)?.sevenDaysBefore ?? '7 Days Before', 
        'subtitle': AppLocalizations.of(context)?.advanceReminder ?? 'Advance reminder'
      },
      {
        'title': AppLocalizations.of(context)?.dueToday ?? 'Due Today', 
        'subtitle': AppLocalizations.of(context)?.dueDateReminder ?? 'Due date reminder'
      },
      {
        'title': AppLocalizations.of(context)?.manual ?? 'Manual', 
        'subtitle': AppLocalizations.of(context)?.manualReminder ?? 'Manual reminder'
      },
    ];
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = index == _selectedTabIndex;
          
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTabIndex = index;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    Text(
                      tab['title']!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tab['subtitle']!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? Colors.white.withOpacity(0.8) : AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildTemplateEditor() {
    TextEditingController currentController;
    String templateType;
    
    switch (_selectedTabIndex) {
      case 0:
        currentController = widget.template7DaysController;
        templateType = AppLocalizations.of(context)?.sevenDayAdvanceReminder ?? '7-day advance reminder';
        break;
      case 1:
        currentController = widget.templateDueTodayController;
        templateType = AppLocalizations.of(context)?.dueDateReminder ?? 'due date reminder';
        break;
      case 2:
        currentController = widget.templateManualController;
        templateType = AppLocalizations.of(context)?.manualReminder ?? 'manual reminder';
        break;
      default:
        currentController = widget.templateManualController;
        templateType = AppLocalizations.of(context)?.manualReminder ?? 'manual reminder';
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${AppLocalizations.of(context)?.templateFor ?? 'Template for'} $templateType:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '${currentController.text.length}/1000',
              style: TextStyle(
                fontSize: 12,
                color: currentController.text.length > 900 
                    ? AppTheme.warningColor 
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        TextFormField(
          controller: currentController,
          maxLines: 6,
          maxLength: 1000,
          style: TextStyle(
            fontSize: 14,
            fontFamily: 'monospace',
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)?.enterMessageTemplate ?? 'Enter your message template here...',
            hintStyle: TextStyle(
              color: AppTheme.textHint,
              fontFamily: 'Inter',
            ),
            filled: true,
            fillColor: Colors.white,
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
            contentPadding: const EdgeInsets.all(12),
            counterText: '', // Hide the built-in counter
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return AppLocalizations.of(context)?.templateCannotBeEmpty ?? 'Template cannot be empty';
            }
            if (value.length > 1000) {
              return AppLocalizations.of(context)?.templateTooLong ?? 'Template must be less than 1000 characters';
            }
            return null;
          },
        ),
        
        // Validation errors
        if (_validationErrors.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildValidationErrors(),
        ],
        
        // Preview section
        const SizedBox(height: 12),
        _buildTemplatePreview(currentController.text),
      ],
    );
  }
  
  Widget _buildTemplatePreview(String template) {
    // Replace variables with sample data for preview
    String preview = template
        .replaceAll('{client_name}', 'Иван Петров')
        .replaceAll('{installment_amount}', '15,000')
        .replaceAll('{due_date}', '25.01.2025')
        .replaceAll('{days_remaining}', '7')
        .replaceAll('{product_name}', 'iPhone 15')
        .replaceAll('{total_amount}', '120,000');
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.preview,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)?.preview ?? 'Preview:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            preview.isEmpty 
                ? AppLocalizations.of(context)?.templatePreviewPlaceholder ?? 'Template preview will appear here...' 
                : preview,
            style: TextStyle(
              fontSize: 13,
              color: preview.isEmpty ? AppTheme.textHint : AppTheme.textPrimary,
              fontStyle: preview.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVariablesHelper() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)?.availableVariables ?? 'Available Variables:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableVariables.map((variable) {
              return GestureDetector(
                onTap: () {
                  _insertVariable(variable);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        variable,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.add,
                        size: 12,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 12),
          
          // Variable descriptions
          Column(
            children: _availableVariables.map((variable) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      variable,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '—',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getVariableDescriptions(context)[variable] ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildValidationErrors() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 16,
                color: AppTheme.errorColor,
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)?.templateIssues ?? 'Template Issues:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.errorColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._validationErrors.map((error) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  void _insertVariable(String variable) {
    TextEditingController currentController;
    
    switch (_selectedTabIndex) {
      case 0:
        currentController = widget.template7DaysController;
        break;
      case 1:
        currentController = widget.templateDueTodayController;
        break;
      case 2:
        currentController = widget.templateManualController;
        break;
      default:
        currentController = widget.templateManualController;
    }
    
    final text = currentController.text;
    final selection = currentController.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      variable,
    );
    
    currentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + variable.length,
      ),
    );
    
    // Provide haptic feedback
    HapticFeedback.lightImpact();
  }
}