import 'package:flutter/material.dart';

class ModuleCard extends StatelessWidget {
  final String title;
  const ModuleCard({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(title),
      ),
    );
  }
}
