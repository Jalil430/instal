import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/localization/app_localizations.dart';

class WhatsAppTemplateEditorMobile extends StatefulWidget {
  final TextEditingController template7DaysController;
  final TextEditingController templateDueTodayController;
  final TextEditingController templateManualController;

  const WhatsAppTemplateEditorMobile({
    super.key,
    required this.template7DaysController,
    required this.templateDueTodayController,
    required this.templateManualController,
  });

  @override
  State<WhatsAppTemplateEditorMobile> createState() => _WhatsAppTemplateEditorMobileState();
}

class _WhatsAppTemplateEditorMobileState extends State<WhatsAppTemplateEditorMobile> {
  int _selectedTabIndex = 0;
  List<String> _validationErrors = [];
  bool _showVariablesPanel = false;
  
  final List<String> _availableVariables = [
    '{client_name}',
    '{installment_amount}',
    '{due_date}',
    '{days_remaining}',
    '{product_name}',
    '{total_amount}',
  ];
  
  // This method isn't directly referenced but we'll keep it for possible future use
  Map<String, String> _getVariableDescriptions(BuildContext context) => {
    '{client_name}': AppLocalizations.of(context)?.clientFullName ?? 'Client\'s name',
    '{installment_amount}': AppLocalizations.of(context)?.monthlyPaymentAmount ?? 'Payment amount',
    '{due_date}': AppLocalizations.of(context)?.paymentDueDate ?? 'Due date',
    '{days_remaining}': AppLocalizations.of(context)?.daysUntilDueDate ?? 'Days until due',
    '{product_name}': AppLocalizations.of(context)?.productServiceName ?? 'Product name',
    '{total_amount}': AppLocalizations.of(context)?.totalInstallmentPrice ?? 'Total price',
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
      errors.add(AppLocalizations.of(context)?.templateTooLong ?? 'Template too long (max 1000 chars)');
    }
    
    // Check for invalid variable syntax
    RegExp variablePattern = RegExp(r'\{[^}]*\}');
    Iterable<Match> matches = variablePattern.allMatches(template);
    
    for (Match match in matches) {
      String variable = match.group(0)!;
      if (!_availableVariables.contains(variable)) {
        errors.add('${AppLocalizations.of(context)?.invalidVariable ?? 'Invalid'}: $variable');
      }
    }
    
    // Check for unclosed braces
    int openBraces = template.split('{').length - 1;
    int closeBraces = template.split('}').length - 1;
    if (openBraces != closeBraces) {
      errors.add(AppLocalizations.of(context)?.unmatchedBraces ?? 'Unmatched braces');
    }
    
    // Warn if no variables are used
    bool hasVariables = _availableVariables.any((variable) => template.contains(variable));
    if (!hasVariables) {
      errors.add(AppLocalizations.of(context)?.considerUsingVariables ?? 'Add variables for personalization');
    }
    
    return errors;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab selector - more compact for mobile
          _buildTabSelector(),
          const SizedBox(height: 12),
          
          // Template editor
          _buildTemplateEditor(),
          
          // Toggle variables panel
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showVariablesPanel = !_showVariablesPanel;
              });
            },
            icon: Icon(
              _showVariablesPanel ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16,
              color: AppTheme.primaryColor,
            ),
            label: Text(
              _showVariablesPanel 
                ? AppLocalizations.of(context)?.hideVariables ?? 'Спрятать переменные'
                : AppLocalizations.of(context)?.showVariables ?? 'Показать переменные',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.primaryColor,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            ),
          ),
          
          // Collapsible variables section
          if (_showVariablesPanel) ...[
            const SizedBox(height: 8),
            _buildVariablesHelper(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildTabSelector() {
    final tabs = [
      {
        'title': AppLocalizations.of(context)?.sevenDaysBefore ?? '7 Days Before',
      },
      {
        'title': AppLocalizations.of(context)?.dueToday ?? 'Due Today', 
      },
      {
        'title': AppLocalizations.of(context)?.manual ?? 'Manual',
      },
    ];
    
    return Container(
      height: 36, // Fixed height for mobile
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(6),
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
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tab['title']!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
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
        templateType = AppLocalizations.of(context)?.sevenDayAdvanceReminder ?? '7-day advance';
        break;
      case 1:
        currentController = widget.templateDueTodayController;
        templateType = AppLocalizations.of(context)?.dueDateReminder ?? 'due date';
        break;
      case 2:
        currentController = widget.templateManualController;
        templateType = AppLocalizations.of(context)?.manualReminder ?? 'manual';
        break;
      default:
        currentController = widget.templateManualController;
        templateType = AppLocalizations.of(context)?.manualReminder ?? 'manual';
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$templateType',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '${currentController.text.length}/1000',
              style: TextStyle(
                fontSize: 11,
                color: currentController.text.length > 900 
                    ? AppTheme.warningColor 
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        
        TextFormField(
          controller: currentController,
          maxLines: 5, // Fewer lines for mobile
          maxLength: 1000,
          style: TextStyle(
            fontSize: 13, // Smaller font for mobile
            fontFamily: 'monospace',
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)?.enterMessageTemplate ?? 'Enter message...',
            hintStyle: TextStyle(
              color: AppTheme.textHint,
              fontFamily: 'Inter',
              fontSize: 13,
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
            contentPadding: const EdgeInsets.all(8), // Less padding for mobile
            counterText: '', // Hide the built-in counter
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return AppLocalizations.of(context)?.templateCannotBeEmpty ?? 'Template required';
            }
            if (value.length > 1000) {
              return AppLocalizations.of(context)?.templateTooLong ?? 'Too long (max 1000)';
            }
            return null;
          },
        ),
        
        // Validation errors - more compact for mobile
        if (_validationErrors.isNotEmpty) ...[
          const SizedBox(height: 6),
          _buildValidationErrors(),
        ],
        
        // Preview section - more compact for mobile
        const SizedBox(height: 10),
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
      padding: const EdgeInsets.all(10), // Less padding for mobile
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
                size: 14, // Smaller for mobile
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context)?.preview ?? 'Preview:',
                style: TextStyle(
                  fontSize: 11, // Smaller for mobile
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4), // Less space for mobile
          Text(
            preview.isEmpty 
                ? AppLocalizations.of(context)?.templatePreviewPlaceholder ?? 'Preview will appear here...' 
                : preview,
            style: TextStyle(
              fontSize: 12, // Smaller for mobile
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
      padding: const EdgeInsets.all(12), // Less padding for mobile
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)?.availableVariables ?? 'Available Variables:',
            style: TextStyle(
              fontSize: 12, // Smaller for mobile
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          
          // Variables as chips in a Wrap
          Wrap(
            spacing: 6, // Less spacing for mobile
            runSpacing: 6,
            children: _availableVariables.map((variable) {
              return GestureDetector(
                onTap: () {
                  _insertVariable(variable);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), // Smaller padding for mobile
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
                          fontSize: 11, // Smaller for mobile
                          fontFamily: 'monospace',
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.add,
                        size: 10, // Smaller for mobile
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
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
      padding: const EdgeInsets.all(8), // Less padding for mobile
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 14, // Smaller for mobile
                color: AppTheme.errorColor,
              ),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context)?.templateIssues ?? 'Issues:',
                style: TextStyle(
                  fontSize: 11, // Smaller for mobile
                  fontWeight: FontWeight.w600,
                  color: AppTheme.errorColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4), // Less space for mobile
          ..._validationErrors.map((error) => Padding(
            padding: const EdgeInsets.only(bottom: 2), // Less padding for mobile
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 3, // Smaller for mobile
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    error,
                    style: TextStyle(
                      fontSize: 11, // Smaller for mobile
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
    TextEditingController currentController = _getCurrentController();
    
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