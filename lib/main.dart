import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'pages/login_page.dart';
import 'models/service.dart';
import 'pages/booking_page.dart';
import 'pages/admin_page.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthProvider extends ChangeNotifier {
  String _role = 'client';
  bool get isAdmin => _role == 'admin';
  String get role => _role;

  Future<void> loadRole(String? userId) async {
    if (userId == null) {
      _role = 'client';
    } else {
      _role = await AuthService.getUserRole(userId);
    }
    notifyListeners();
  }

  void refreshRole() {
    loadRole(FirebaseAuth.instance.currentUser?.uid);
  }
}

StreamSubscription? _bookingSubscription;

void listenNewBookings() {
  _bookingSubscription?.cancel();

  _bookingSubscription = FirebaseFirestore.instance
      .collection('appointments')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .listen((snapshot) {});
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  listenNewBookings();

  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: const RossiApp(),
    ),
  );
}

class RossiApp extends StatelessWidget {
  const RossiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Servizi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE58799)),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();

    FirebaseAuth.instance.authStateChanges().listen((user) {
      final provider = Provider.of<AuthProvider>(context, listen: false);
      provider.loadRole(user?.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const CatalogoPage();
        }

        return const LoginPage();
      },
    );
  }
}

Widget backgroundContainer({required Widget child}) {
  return Container(
    width: double.infinity,
    height: double.infinity,
    decoration: const BoxDecoration(
      image: DecorationImage(
        image: AssetImage('assets/images/fondo2_app.png'),
        fit: BoxFit.cover,
      ),
    ),
    child: Container(color: Colors.white.withOpacity(0.65), child: child),
  );
}

class CatalogoPage extends StatefulWidget {
  const CatalogoPage({super.key});

  @override
  State<CatalogoPage> createState() => _CatalogoPageState();
}

class _CatalogoPageState extends State<CatalogoPage> {
  String selectedCategory = 'unghie';

  static const Color gold = Color(0xFFDDA33B);
  static const Color dark = Color(0xFF111111);

  Future<void> openWebsite() async {
    final Uri url = Uri.parse('https://www.rosibeautypremium.it');

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir el sitio web');
    }
  }

  Widget categoryButton(String title, String category) {
    final bool selected = selectedCategory == category;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedCategory = category;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: selected ? gold : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: gold, width: 1.4),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: selected ? Colors.white : dark,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: <Widget>[
          if (Provider.of<AuthProvider>(context).isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
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
            const SizedBox(height: 25),

            InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: openWebsite,
              child: Image.asset(
                'assets/images/logorosipremium.png',
                height: 115,
              ),
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: 245,
              height: 42,
              child: OutlinedButton.icon(
                onPressed: openWebsite,
                icon: const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFFDDA33B),
                  size: 20,
                ),
                label: const Text(
                  "Sfoglia la Rivista Premium",
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDDA33B), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Beauty Servizi',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 15),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                children: [
                  categoryButton('Unghie', 'unghie'),
                  categoryButton('Ciglia', 'lashes'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('services')
                    .where('active', isEqualTo: true)
                    .where('category', isEqualTo: selectedCategory)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text("Nessun servizio disponibile"),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 5,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final service = Service.fromFirestore(
                        docs[index].data() as Map<String, dynamic>,
                      );

                      return ServiceAccordionItemWrapper(
                        service: service,
                        index: index,
                      );
                    },
                  );
                },
              ),
            ),

            GestureDetector(
              onTap: openWebsite,
              child: const Text(
                "Catalogo completo su: www.rosibeautypremium.it",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDDA33B),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),

            TextButton(
              onPressed: () {
                FirebaseAuth.instance.signOut();
              },
              child: const Text(
                "Logout",
                style: TextStyle(
                  color: Color(0xFF7A3E3E),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

/// 🔥 WRAPPER (controla un solo acordeón abierto)
class ServiceAccordionItemWrapper extends StatefulWidget {
  final Service service;
  final int index;

  const ServiceAccordionItemWrapper({
    super.key,
    required this.service,
    required this.index,
  });

  @override
  State<ServiceAccordionItemWrapper> createState() =>
      _ServiceAccordionItemWrapperState();
}

class _ServiceAccordionItemWrapperState
    extends State<ServiceAccordionItemWrapper> {
  static int? expandedIndex;

  @override
  Widget build(BuildContext context) {
    final isExpanded = expandedIndex == widget.index;

    return ServiceAccordionItem(
      service: widget.service,
      isExpanded: isExpanded,
      onTap: () {
        setState(() {
          if (isExpanded) {
            expandedIndex = null;
          } else {
            expandedIndex = widget.index;
          }
        });
      },
    );
  }
}

/// 🔥 ACORDEÓN PRO
class ServiceAccordionItem extends StatelessWidget {
  final Service service;
  final bool isExpanded;
  final VoidCallback onTap;

  const ServiceAccordionItem({
    super.key,
    required this.service,
    required this.isExpanded,
    required this.onTap,
  });

  static const Color gold = Color(0xFFDDA33B);
  static const Color dark = Color(0xFF111111);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: gold, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: SizedBox(
              height: 45,
              child: Row(
                children: [
                  const SizedBox(width: 8),

                  SizedBox(
                    width: 35,
                    child: Center(
                      child: Icon(
                        isExpanded ? Icons.remove : Icons.add,
                        color: dark,
                        size: 22,
                      ),
                    ),
                  ),

                  Expanded(
                    child: Text(
                      service.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: dark,
                      ),
                    ),
                  ),

                  const SizedBox(width: 35),
                ],
              ),
            ),
          ),

          AnimatedCrossFade(
            firstChild: const SizedBox(),
            secondChild: _expandedContent(context),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 400),
          ),
        ],
      ),

      /* ListTile(
            dense: true,
            visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            onTap: onTap,
            leading: AnimatedRotation(
              turns: isExpanded ? 0.125 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                isExpanded ? Icons.remove : Icons.add,
                color: dark,
                size: 28,
              ),
            ),
            title: Text(
              service.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: dark,
                fontSize: 12,
              ),
            ),
          ), */
    );
  }

  Widget _expandedContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 15),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(9)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                barrierColor: Colors.black87,
                builder: (context) {
                  return Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.all(10),
                    child: Stack(
                      children: [
                        InteractiveViewer(
                          minScale: 1,
                          maxScale: 5,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: service.image.startsWith('http')
                                ? Image.network(
                                    service.image,
                                    fit: BoxFit.contain,
                                  )
                                : Image.asset(
                                    service.image,
                                    fit: BoxFit.contain,
                                  ),
                          ),
                        ),

                        Positioned(
                          top: 10,
                          right: 10,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },

            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: service.image.startsWith('http')
                  ? Image.network(
                      service.image,
                      width: 85,
                      height: 85,
                      fit: BoxFit.cover,
                    )
                  : Image.asset(
                      service.image,
                      width: 85,
                      height: 85,
                      fit: BoxFit.cover,
                    ),
            ),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: Column(
              children: [
                Text(
                  service.price,
                  style: const TextStyle(
                    fontSize: 22,
                    color: gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookingPage(service: service),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dark,
                      foregroundColor: gold,
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: const Text(
                      "Prenotare",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
