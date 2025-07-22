// lib/pages/planner_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PlannerPage extends StatelessWidget {
  const PlannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Your Plans",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child:
            Text("Hike plans will be listed here.", style: GoogleFonts.lato()),
      ),
    );
  }
}
