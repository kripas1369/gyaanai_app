import 'package:flutter/material.dart';

class SubjectProgressScreen extends StatelessWidget {
  const SubjectProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subject progress')),
      body: const Center(child: Text('Per-subject stats')),
    );
  }
}
