import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/auth_service.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final nomeController = TextEditingController();
  final cognomeController = TextEditingController();
  final telefonoController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

  static const Color gold = Color(0xFFDDA33B);
  static const Color dark = Color(0xFF111111);
  static const Color textBrown = Color(0xFF74565A);

  Widget registerInput(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textBrown,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 40,
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFEDEDED),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: gold, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: gold, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> register() async {
    final nome = nomeController.text.trim();
    final cognome = cognomeController.text.trim();
    final telefono = telefonoController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (nome.isEmpty ||
        cognome.isEmpty ||
        telefono.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Completa tutti i campi')));
      return;
    }

    setState(() => isLoading = true);

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await AuthService.createUserProfile(
        userId: credential.user!.uid,
        nome: nome,
        cognome: cognome,
        telefono: telefono,
        email: email,
      );

      if (!mounted) return;

      Provider.of<AuthProvider>(
        context,
        listen: false,
      ).loadRole(credential.user!.uid);

      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Errore: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Errore: $e')));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/fondo2_app.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 10),

                Image.asset(
                  'assets/images/logorosipremium.png',
                  height: 100,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 8),

                const Text(
                  'Creare un account',
                  style: TextStyle(
                    color: textBrown,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Inserisci il tuo nome e cognome, indirizzo email,\n'
                  'numero di telefono e password per registrarti a\n'
                  'questa applicazione',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textBrown,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 18),

                registerInput(nomeController, 'Nome e Cognome'),

                const SizedBox(height: 13),

                registerInput(
                  emailController,
                  'Email',
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 13),

                registerInput(
                  telefonoController,
                  'Telefono',
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 13),

                registerInput(passwordController, 'Password', obscure: true),

                const SizedBox(height: 32),

                SizedBox(
                  width: 205,
                  height: 53,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dark,
                      foregroundColor: gold,
                      elevation: 7,
                      shadowColor: Colors.black.withOpacity(0.45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: gold,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Registrati',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 55),

                const Text(
                  'Facendo clic su Continua, accetti i nostri Termini di\n'
                  'Servizio e la nostra Informativa sulla Privacy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textBrown,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
