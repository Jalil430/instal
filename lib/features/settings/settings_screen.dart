import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../main.dart';
import '../../shared/widgets/custom_button.dart';
import '../auth/presentation/widgets/auth_service_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguage = 'ru';
  String? _dbPath;

  @override
  void initState() {
    super.initState();
    _loadDbPath();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLanguage();
  }

  void _loadLanguage() {
    final locale = AppLocalizations.of(context)?.locale;
    if (locale != null) {
      if (_selectedLanguage != locale.languageCode) {
        setState(() {
          _selectedLanguage = locale.languageCode;
        });
      }
    }
  }

  Future<void> _loadDbPath() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'instal.db');
    setState(() {
      _dbPath = path;
    });
  }

  void _changeLanguage(String langCode) {
    final locale = Locale(langCode);
    final localeSetter = LocaleSetter.of(context);
    localeSetter?.setLocale(locale);
  }

  Future<void> _openDbFolder() async {
    if (_dbPath == null) return;
    final folder = p.dirname(_dbPath!);
    final uri = Uri.file(folder);
    await launchUrl(uri);
  }

  Future<void> _logout() async {
    try {
      final authService = AuthServiceProvider.of(context);
      await authService.logout();
      
      if (mounted) {
        context.go('/auth/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
            color: AppTheme.surfaceColor,
            child: Row(
              children: [
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context)?.settings ?? 'Настройки',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Language
                  Text(
                    AppLocalizations.of(context)?.language ?? 'Язык',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _LanguageOption(
                        label: AppLocalizations.of(context)?.languageRussian ?? 'Русский',
                        value: 'ru',
                        groupValue: _selectedLanguage,
                        onChanged: _changeLanguage,
                      ),
                      const SizedBox(width: 24),
                      _LanguageOption(
                        label: AppLocalizations.of(context)?.languageEnglish ?? 'English',
                        value: 'en',
                        groupValue: _selectedLanguage,
                        onChanged: _changeLanguage,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Database Path Section
                  Text(
                    AppLocalizations.of(context)?.localDatabase ?? 'Локальная база данных',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_dbPath != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          _dbPath!,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        CustomButton(
                          onPressed: _openDbFolder,
                          text: AppLocalizations.of(context)?.openFolder ?? 'Открыть папку',
                          icon: Icons.folder_open,
                          showIcon: true,
                        ),
                      ],
                    ),
                  if (_dbPath == null)
                    const CircularProgressIndicator(),
                  const SizedBox(height: 32),
                  
                  // Account Section
                  Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    onPressed: _logout,
                    text: 'Logout',
                    icon: Icons.logout,
                    showIcon: true,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  const _LanguageOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => onChanged(value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: groupValue,
            onChanged: (v) => onChanged(v!),
            visualDensity: VisualDensity.compact,
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
} 