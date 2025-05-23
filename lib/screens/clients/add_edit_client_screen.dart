import 'package:fluent_ui/fluent_ui.dart';
import '../../models/client.dart';
import '../../services/database_service.dart';
import '../../utils/theme.dart';

class AddEditClientScreen extends StatefulWidget {
  final Client? client;

  const AddEditClientScreen({
    super.key,
    this.client,
  });

  @override
  State<AddEditClientScreen> createState() => _AddEditClientScreenState();
}

class _AddEditClientScreenState extends State<AddEditClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _passportNumberController = TextEditingController();
  final _addressController = TextEditingController();
  
  bool _isLoading = false;
  bool get isEditing => widget.client != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _fullNameController.text = widget.client!.fullName;
      _contactNumberController.text = widget.client!.contactNumber;
      _passportNumberController.text = widget.client!.passportNumber;
      _addressController.text = widget.client!.address;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _contactNumberController.dispose();
    _passportNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (isEditing) {
        final updatedClient = widget.client!.copyWith(
          fullName: _fullNameController.text,
          contactNumber: _contactNumberController.text,
          passportNumber: _passportNumberController.text,
          address: _addressController.text,
        );
        await DatabaseService.updateClient(updatedClient);
      } else {
        final newClient = Client(
          id: '',
          userId: '',
          fullName: _fullNameController.text,
          contactNumber: _contactNumberController.text,
          passportNumber: _passportNumberController.text,
          address: _addressController.text,
          createdAt: DateTime.now(),
        );
        await DatabaseService.insertClient(newClient);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('Error'),
            content: Text('Failed to save client: $e'),
            actions: [
              Button(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      appBar: NavigationAppBar(
        title: Text(isEditing ? 'Edit Client' : 'Add Client'),
        leading: IconButton(
          icon: const Icon(FluentIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      content: ScaffoldPage(
        content: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  Card(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Client Information',
                          style: AppTheme.subtitleStyle,
                        ),
                        const SizedBox(height: 24),
                        
                        InfoLabel(
                          label: 'Full Name',
                          isHeader: true,
                          child: TextFormBox(
                            controller: _fullNameController,
                            placeholder: 'Enter client\'s full name',
                            prefix: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(FluentIcons.contact),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Full name is required';
                              }
                              if (value.length < 3) {
                                return 'Name must be at least 3 characters';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        InfoLabel(
                          label: 'Contact Number',
                          isHeader: true,
                          child: TextFormBox(
                            controller: _contactNumberController,
                            placeholder: 'Enter phone number',
                            prefix: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(FluentIcons.phone),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Contact number is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        InfoLabel(
                          label: 'Passport Number',
                          isHeader: true,
                          child: TextFormBox(
                            controller: _passportNumberController,
                            placeholder: 'Enter passport number',
                            prefix: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(FluentIcons.contact_card),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Passport number is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        InfoLabel(
                          label: 'Address',
                          isHeader: true,
                          child: TextFormBox(
                            controller: _addressController,
                            placeholder: 'Enter full address',
                            prefix: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(FluentIcons.map_pin),
                            ),
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Address is required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Button(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _isLoading ? null : _saveClient,
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: ProgressRing(strokeWidth: 2),
                              )
                            : Text(isEditing ? 'Save Changes' : 'Add Client'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 