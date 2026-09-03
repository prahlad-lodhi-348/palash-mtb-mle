import 'package:flutter/material.dart';
import 'integration_demo_page.dart';

void main() {
  runApp(const PalashApp());
}

class PalashApp extends StatelessWidget {
  const PalashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PALASH MTB-MLE',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PALASH MTB-MLE'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school, size: 80, color: Colors.teal),
              SizedBox(height: 20),
              Text(
                'Mother Tongue-Based Multilingual Education',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'Tablet app scaffold ready for lesson flow, worksheets, and AI language support.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const IntegrationDemoPage()));
                },
                child: const Text('Open Integration Demo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
