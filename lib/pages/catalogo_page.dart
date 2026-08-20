import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/booking_selection.dart';
import '../models/service.dart';
import '../providers/auth_provider.dart';
import '../widgets/background_container.dart';
import '../widgets/service_accordion_item.dart';
import 'admin_page.dart';
import 'booking_page.dart';

class CatalogoPage extends StatefulWidget {
  const CatalogoPage({super.key});

  @override
  State<CatalogoPage> createState() => _CatalogoPageState();
}

class _CatalogoPageState extends State<CatalogoPage> {
  String selectedCategory = 'unghie';

  static const Color gold = Color(0xFFDDA33B);
  static const Color dark = Color(0xFF111111);

  final Map<String, BookingSelection> _selections = {};

  late Stream<QuerySnapshot<Map<String, dynamic>>> _servicesStream;

  String _serviceKey(Service service) {
    if (service.id.isNotEmpty) {
      return service.id;
    }

    return '${service.category}_${service.name}';
  }

  bool _isServiceSelected(Service service) {
    return _selections.containsKey(_serviceKey(service));
  }

  BookingSelection? _selectionFor(Service service) {
    return _selections[_serviceKey(service)];
  }

  List<ServiceExtra> _selectedExtrasFor(Service service) {
    return _selectionFor(service)?.selectedExtras ?? const [];
  }

  int get _totalDuration {
    return _selections.values.fold<int>(
      0,
      (total, selection) => total + selection.totalDuration,
    );
  }

  double get _totalPrice {
    return _selections.values.fold<double>(
      0,
      (total, selection) => total + selection.totalPrice,
    );
  }

  int get _servicesCount => _selections.length;

  void _toggleService(Service service) {
    final key = _serviceKey(service);

    setState(() {
      if (_selections.containsKey(key)) {
        _selections.remove(key);
      } else {
        _selections[key] = BookingSelection(service: service);
      }
    });
  }

  void _toggleExtra(Service service, ServiceExtra extra) {
    final key = _serviceKey(service);
    final currentSelection = _selections[key];

    debugPrint(
      'EXTRA DEBUG -> '
      'name=${extra.name}, '
      'price=${extra.price}, '
      'duration=${extra.duration}',
    );

    if (currentSelection == null) {
      return;
    }

    final extras = List<ServiceExtra>.from(currentSelection.selectedExtras);

    final existingIndex = extras.indexWhere(
      (selectedExtra) => selectedExtra.id == extra.id,
    );

    setState(() {
      if (existingIndex >= 0) {
        extras.removeAt(existingIndex);
      } else {
        extras.add(extra);
      }

      _selections[key] = currentSelection.copyWith(selectedExtras: extras);
    });

    debugPrint(
      'TOTAL DEBUG -> '
      'duration=${_selections[key]?.totalDuration}, '
      'price=${_selections[key]?.totalPrice}',
    );
  }

  void _clearSelections() {
    setState(() {
      _selections.clear();
    });
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) {
      return '$remainingMinutes min';
    }

    if (remainingMinutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remainingMinutes}min';
  }

  String _formatPrice(double price) {
    return '${price.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  Future<void> _continueToBooking() async {
    if (_selections.isEmpty) {
      return;
    }

    final selections = _selections.values.toList();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingPage(selections: selections),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _updateServicesStream();
  }

  void _updateServicesStream() {
    _servicesStream = FirebaseFirestore.instance
        .collection('services')
        .where('active', isEqualTo: true)
        .where('category', isEqualTo: selectedCategory)
        .snapshots();
  }

  Future<void> openWebsite() async {
    final Uri url = Uri.parse('https://www.rosibeautypremium.it');

    final bool opened = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il sito web')),
      );
    }
  }

  Widget categoryButton(String title, String category) {
    final bool isSelected = selectedCategory == category;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (selectedCategory == category) {
            return;
          }

          setState(() {
            selectedCategory = category;
            _updateServicesStream();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: isSelected ? gold : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: gold, width: 1.4),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : dark,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionSummary() {
    if (_selections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: gold, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shopping_bag_outlined,
                        color: gold,
                        size: 21,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '$_servicesCount '
                        '${_servicesCount == 1 ? 'servizio' : 'servizi'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: dark,
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  _formatDuration(_totalDuration),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: dark,
                  ),
                ),

                const SizedBox(width: 16),

                Text(
                  _formatPrice(_totalPrice),
                  style: const TextStyle(
                    color: gold,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                TextButton(
                  onPressed: _clearSelections,
                  child: const Text(
                    'SVUOTA',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: ElevatedButton(
                    onPressed: _continueToBooking,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: dark,
                      foregroundColor: gold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: const Text(
                      'CONTINUA',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (authProvider.isLoadingRole)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: gold),
                ),
              ),
            )
          else if (authProvider.isAdmin)
            IconButton(
              icon: const Icon(
                Icons.admin_panel_settings,
                color: dark,
                size: 28,
              ),
              tooltip: 'Gestione prenotazioni',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminPage()),
                );
              },
            ),
        ],
      ),
      body: backgroundContainer(
        child: Column(
          children: [
            const SizedBox(height: 15),

            InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: openWebsite,
              child: Image.asset(
                'assets/images/logorosipremium.png',
                height: 105,
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(height: 5),

            SizedBox(
              width: 245,
              height: 42,
              child: OutlinedButton.icon(
                onPressed: openWebsite,
                icon: const Icon(
                  Icons.menu_book_rounded,
                  color: gold,
                  size: 20,
                ),
                label: const Text(
                  'Sfoglia la Rivista Premium',
                  style: TextStyle(
                    color: dark,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: gold, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Beauty Servizi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: dark,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              'Seleziona uno o più servizi',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                children: [
                  categoryButton('Unghie', 'unghie'),
                  categoryButton('Ciglia', 'lashes'),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _servicesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Errore durante il caricamento: '
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final documents = snapshot.data?.docs ?? [];

                  if (documents.isEmpty) {
                    return const Center(
                      child: Text('Nessun servizio disponibile'),
                    );
                  }

                  return ListView.builder(
                    key: PageStorageKey<String>('services_$selectedCategory'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 5,
                    ),
                    itemCount: documents.length,
                    itemBuilder: (context, index) {
                      final document = documents[index];

                      final service = Service.fromFirestore(
                        document.data(),
                        id: document.id,
                      );

                      return ServiceAccordionItemWrapper(
                        key: ValueKey(document.id),
                        service: service,
                        index: index,
                        isSelected: _isServiceSelected(service),
                        selectedExtras: _selectedExtrasFor(service),
                        onToggleService: _toggleService,
                        onToggleExtra: _toggleExtra,
                      );
                    },
                  );
                },
              ),
            ),

            GestureDetector(
              onTap: openWebsite,
              child: const Text(
                'Catalogo completo su: '
                'www.rosibeautypremium.it',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: gold,
                  decoration: TextDecoration.underline,
                  decorationColor: gold,
                ),
              ),
            ),

            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              child: const Text(
                'Logout',
                style: TextStyle(
                  color: Color(0xFF7A3E3E),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            _buildSelectionSummary(),
          ],
        ),
      ),
    );
  }
}
