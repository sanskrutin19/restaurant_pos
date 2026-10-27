import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

class FloorPlanDesigner extends ConsumerStatefulWidget {
  const FloorPlanDesigner({super.key});

  @override
  ConsumerState<FloorPlanDesigner> createState() => _FloorPlanDesignerState();
}

class _FloorPlanDesignerState extends ConsumerState<FloorPlanDesigner> {
  Map<String, Offset> _positions = {};
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      setState(() {
        _positions = settings.tablePositions.map(
          (key, value) => MapEntry(key, Offset(value['x'].toDouble(), value['y'].toDouble())),
        );
        _isLoaded = true;
      });
    });
  }

  void _savePositions() {
    final settings = ref.read(settingsProvider);
    final jsonPositions = _positions.map(
      (key, value) => MapEntry(key, {'x': value.dx, 'y': value.dy}),
    );
    final newSettings = settings.copyWith(tablePositions: jsonPositions);
    ref.read(settingsProvider.notifier).saveSettings(newSettings);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Floor plan saved'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final totalTables = ref.watch(settingsProvider).totalTables;
    final size = MediaQuery.of(context).size;
    final canvasWidth = size.width - 200; // sidebar etc
    final canvasHeight = size.height - 100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Floor Plan Designer'),
        actions: [
          ElevatedButton.icon(
            onPressed: _savePositions,
            icon: const Icon(Icons.save),
            label: const Text('Save Plan'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        color: Colors.grey[200],
        child: Stack(
          children: [
            // Instructions
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                child: const Text('Drag tables to position them according to your restaurant layout.', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            // The Canvas
            ...List.generate(totalTables, (index) {
              final tableNum = index + 1;
              final tableId = tableNum.toString();
              
              // Default position if not set
              if (!_positions.containsKey(tableId)) {
                _positions[tableId] = Offset(100.0 + (index % 5) * 120, 100.0 + (index ~/ 5) * 120);
              }

              final pos = _positions[tableId]!;

              return Positioned(
                left: pos.dx,
                top: pos.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _positions[tableId] = Offset(
                        (pos.dx + details.delta.dx).clamp(0, canvasWidth - 80),
                        (pos.dy + details.delta.dy).clamp(0, canvasHeight - 80),
                      );
                    });
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.deepOrange, width: 2),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))],
                    ),
                    child: Center(
                      child: Text(
                        'T$tableNum',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepOrange),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
