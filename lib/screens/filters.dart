import 'package:flutter/material.dart';

class Filters extends StatelessWidget {
  final String selectedValue;
  final ValueChanged<String?> onChanged;

  const Filters({Key? key, required this.selectedValue, required this.onChanged}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blueAccent, width: 1.5),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedValue,
            isExpanded: true,
            icon: Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
            style: TextStyle(fontSize: 16, color: Colors.black),
            items: const [
              DropdownMenuItem(value: "1", child: Text("Last 1 Day")),
              DropdownMenuItem(value: "7", child: Text("Last 7 Days")),
              DropdownMenuItem(value: "30", child: Text("Last 30 Days")),
              DropdownMenuItem(value: "all", child: Text("All Time")),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
