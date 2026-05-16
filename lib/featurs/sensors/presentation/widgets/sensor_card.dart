import 'package:flutter/material.dart';

class SensorCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const SensorCard({super.key, required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(15),
      child: ListTile(
        leading: Icon(icon, color: color, size: 40),
        title: Text(label),
        trailing: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }
}