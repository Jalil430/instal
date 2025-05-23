import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../utils/theme.dart';
import 'installments/installments_screen.dart';
import 'clients/clients_screen.dart';
import 'investors/investors_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final viewKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return NavigationView(
      key: viewKey,
      appBar: NavigationAppBar(
        automaticallyImplyLeading: false,
        title: const Text('Instal'),
        height: 48,
      ),
      pane: NavigationPane(
        selected: appState.selectedIndex,
        onChanged: (index) => appState.setSelectedIndex(index),
        displayMode: PaneDisplayMode.compact,
        indicator: EndNavigationIndicator(
          color: AppTheme.primaryColor,
        ),
        items: [
          PaneItem(
            icon: const Icon(FluentIcons.document),
            title: const Text('Installments'),
            body: const InstallmentsScreen(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.people),
            title: const Text('Clients'),
            body: const ClientsScreen(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.money),
            title: const Text('Investors'),
            body: const InvestorsScreen(),
          ),
        ],
      ),
    );
  }
} 