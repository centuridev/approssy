import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'registration_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();

  static const Color gold = Color(0xFFDDA33B);
  static const Color dark = Color(0xFF111111);
  static const Color textBrown = Color(0xFF74565A);
  static const String resetPasswordSuccessMessage =
      'Se l\'indirizzo email è associato a un account, riceverai a breve '
      'un link per reimpostare la password.';

  Future login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      Provider.of<AuthProvider>(
        context,
        listen: false,
      ).loadRole(FirebaseAuth.instance.currentUser?.uid);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${e.message}")));
    }
  }

  String _passwordResetErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Inserisci un indirizzo email valido.';
      case 'too-many-requests':
        return 'Troppe richieste. Riprova più tardi.';
      case 'network-request-failed':
        return 'Impossibile connettersi. Controlla la connessione e riprova.';
      default:
        return 'Non è stato possibile inviare l\'email. Riprova più tardi.';
    }
  }

  void _showResetSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(resetPasswordSuccessMessage)),
    );
  }

  Future<void> _showPasswordResetDialog() async {
    final resetEmail = TextEditingController(text: email.text.trim());
    var isSending = false;
    String? errorMessage;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> sendResetEmail() async {
                final emailToReset = resetEmail.text.trim();

                if (emailToReset.isEmpty) {
                  setDialogState(() {
                    errorMessage = 'Inserisci un indirizzo email valido.';
                  });
                  return;
                }

                setDialogState(() {
                  isSending = true;
                  errorMessage = null;
                });

                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(
                    email: emailToReset,
                  );

                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }

                  Navigator.of(dialogContext).pop();
                  _showResetSuccessMessage();
                } on FirebaseAuthException catch (error) {
                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }

                  if (error.code == 'user-not-found') {
                    Navigator.of(dialogContext).pop();
                    _showResetSuccessMessage();
                    return;
                  }

                  setDialogState(() {
                    isSending = false;
                    errorMessage = _passwordResetErrorMessage(error.code);
                  });
                } catch (_) {
                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }

                  setDialogState(() {
                    isSending = false;
                    errorMessage =
                        'Non è stato possibile inviare l\'email. '
                        'Riprova più tardi.';
                  });
                }
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: const Text(
                  'Reimposta password',
                  style: TextStyle(
                    color: textBrown,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inserisci l\'indirizzo email associato al tuo account.\n'
                      'Ti invieremo un link per reimpostare la password.',
                      style: TextStyle(fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: resetEmail,
                      enabled: !isSending,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: 'Email',
                        errorText: errorMessage,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: gold),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: gold, width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isSending
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();
                          },
                    child: const Text(
                      'ANNULLA',
                      style: TextStyle(
                        color: textBrown,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isSending ? null : sendResetEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dark,
                      foregroundColor: gold,
                    ),
                    child: isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: gold,
                            ),
                          )
                        : const Text(
                            'INVIA EMAIL',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      resetEmail.dispose();
    }
  }

  Widget loginInput(
    TextEditingController controller,
    String label, {
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textBrown,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 43,
          child: TextField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFEDEDED),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/fondo2_app.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 35),

                Image.asset(
                  "assets/images/logorosipremium.png",
                  height: 120,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 45),

                const Text(
                  "Accedi al tuo account",
                  style: TextStyle(
                    color: textBrown,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 38),

                loginInput(email, "Indirizzo email"),

                const SizedBox(height: 18),

                loginInput(password, "Password", obscure: true),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showPasswordResetDialog,
                    style: TextButton.styleFrom(
                      foregroundColor: textBrown,
                      padding: const EdgeInsets.only(top: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Password dimenticata?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 50),

                SizedBox(
                  width: 205,
                  height: 53,
                  child: ElevatedButton(
                    onPressed: login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dark,
                      foregroundColor: gold,
                      elevation: 7,
                      shadowColor: Colors.black.withValues(alpha: 0.45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: const Text(
                      "Accedi",
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 35),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Non hai un account? ",
                      style: TextStyle(
                        color: textBrown,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegistrationPage(),
                          ),
                        );
                      },
                      child: const Text(
                        "Registrati",
                        style: TextStyle(
                          color: textBrown,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
