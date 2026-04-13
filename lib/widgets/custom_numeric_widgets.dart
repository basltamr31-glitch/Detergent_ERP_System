import 'package:flutter/material.dart';

class CustomNumericField extends StatefulWidget {
  final String label;
  final double initialValue;
  final Function(double) onChanged;

  const CustomNumericField({super.key, required this.label, this.initialValue = 0.0, required this.onChanged});

  @override
  State<CustomNumericField> createState() => _CustomNumericFieldState();
}

class _CustomNumericFieldState extends State<CustomNumericField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatValue(widget.initialValue));
  }

  @override
  void didUpdateWidget(covariant CustomNumericField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      if (double.tryParse(_controller.text) != widget.initialValue) {
        // Prevent cursor jumping or unnecessary updates if the user is currently typing and it evaluates to the same double.
        // Wait, CustomNumericField is read-only and uses a showModalBottomSheet. 
        // So we can safely overwrite it.
        _controller.text = _formatValue(widget.initialValue);
      }
    }
  }

  String _formatValue(double value) {
    if (value == 0.0) return '';
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  void _showKeypad() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ModernKeypad(
        label: widget.label,
        controller: _controller,
        onConfirm: (val) => widget.onChanged(val),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showKeypad,
      child: AbsorbPointer(
        child: TextField(
          controller: _controller,
          readOnly: true,
          decoration: InputDecoration(
            labelText: widget.label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ModernKeypad extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final Function(double) onConfirm;

  const _ModernKeypad({required this.label, required this.controller, required this.onConfirm});

  @override
  State<_ModernKeypad> createState() => _ModernKeypadState();
}

class _ModernKeypadState extends State<_ModernKeypad> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
      decoration: const BoxDecoration(color: Color(0xFFF2F2F2), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Cairo')),
          const SizedBox(height: 15),
          // هذا هو حقل المعاينة الذي طلبته
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue, width: 2)),
            child: Text(widget.controller.text.isEmpty ? '0' : widget.controller.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          const SizedBox(height: 15),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
              ...['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0'].map((n) => _btn(n)),
              _btn('⌫', isDelete: true),
            ],
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); widget.onConfirm(double.tryParse(widget.controller.text) ?? 0.0); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(double.infinity, 50)),
            child: const Text('تأكيد', style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  Widget _btn(String text, {bool isDelete = false}) => Material(
    color: isDelete ? Colors.red[50] : Colors.white,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: () => setState(() {
        if (isDelete) {
          if (widget.controller.text.isNotEmpty) widget.controller.text = widget.controller.text.substring(0, widget.controller.text.length - 1);
        } else {
          widget.controller.text += text;
        }
      }),
      child: Center(child: Text(text, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDelete ? Colors.red : Colors.black))),
    ),
  );
}