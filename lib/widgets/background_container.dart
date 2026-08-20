import 'package:flutter/material.dart';

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
    child: Container(color: Colors.white.withValues(alpha: 0.65), child: child),
  );
}
