import 'package:flutter/material.dart';

class SectionButtons extends StatelessWidget {
  final Function(int) onSectionSelected;

  const SectionButtons({Key? key, required this.onSectionSelected}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        SectionButtonItem(title: "📊 Stage Performance", index: 0, onSectionSelected: onSectionSelected),
        SectionButtonItem(title: "🚗 Vehicle Count", index: 1, onSectionSelected: onSectionSelected),
        SectionButtonItem(title: "📜 All Vehicles", index: 2, onSectionSelected: onSectionSelected),
      ],
    );
  }
}

class SectionButtonItem extends StatelessWidget {
  final String title;
  final int index;
  final Function(int) onSectionSelected;

  const SectionButtonItem({
    Key? key,
    required this.title,
    required this.index,
    required this.onSectionSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width / 3 - 20, // Adjust as needed
      child: ElevatedButton(
        onPressed: () => onSectionSelected(index),
        style: ElevatedButton.styleFrom(
          minimumSize: Size(0, 50), // Remove double.infinity
        ),
        child: Text(title, style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
