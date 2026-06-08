import 'package:flutter/material.dart';
import '../../data/models/container_simulation_model.dart';
import '../../data/repositories/logistics_repository_factory.dart';

class ContainerSimulationWidget extends StatefulWidget {
  const ContainerSimulationWidget({super.key});

  @override
  State<ContainerSimulationWidget> createState() => _ContainerSimulationWidgetState();
}

class _ContainerSimulationWidgetState extends State<ContainerSimulationWidget> {
  final _repository = LogisticsRepositoryFactory.make();
  String _selectedContainer = '20ft';
  final _shippingController = TextEditingController(text: '3500');
  final _customsController = TextEditingController(text: '1200');
  
  bool _isSimulating = false;
  ContainerSimulationModel? _simulationResult;

  @override
  void initState() {
    super.initState();
    _runSimulation();
  }

  @override
  void dispose() {
    _shippingController.dispose();
    _customsController.dispose();
    super.dispose();
  }

  Future<void> _runSimulation() async {
    setState(() => _isSimulating = true);
    try {
      final shippingCost = double.tryParse(_shippingController.text) ?? 0.0;
      final customsDuties = double.tryParse(_customsController.text) ?? 0.0;

      final result = await _repository.simulateContainerLoad(
        productQuantities: {'AI-LAP-PRO': 15},
        containerType: _selectedContainer,
        shippingCost: shippingCost,
        customsDuties: customsDuties,
      );

      setState(() => _simulationResult = result);
    } catch (_) {
      // Graceful error state handling
    } finally {
      setState(() => _isSimulating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const goldAccent = Color(0xFFD4AF37); // Matte Gold
    const darkCard = Color(0xFF1F2937);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF374151), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.rtl,
        children: [
          const Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(Icons.directions_boat_outlined, color: goldAccent, size: 22),
              SizedBox(width: 8),
              Text(
                'المحاكاة الحجمية وحساب التكلفة الفعلية (Landed Cost)',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'احسب كفاءة سعة الحاوية اللوجستية وزّع مصاريف الشحن والجمارك على المنتجات.',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 20),

          // Configuration Inputs Row
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'أجور الشحن (USD)',
                  controller: _shippingController,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputField(
                  label: 'الرسوم الجمركية (USD)',
                  controller: _customsController,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Container Type Selector Row
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'نوع حاوية الشحن المستهدفة:',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '20ft', label: Text('حاوية 20 قدم')),
                  ButtonSegment(value: '40ft', label: Text('حاوية 40 قدم')),
                ],
                selected: {_selectedContainer},
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: goldAccent,
                  selectedForegroundColor: Colors.black,
                  backgroundColor: const Color(0xFF111827),
                  foregroundColor: Colors.white,
                ),
                onSelectionChanged: (selection) {
                  setState(() {
                    _selectedContainer = selection.first;
                  });
                  _runSimulation();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_isSimulating)
            const Center(child: CircularProgressIndicator(color: goldAccent))
          else if (_simulationResult != null) ...[
            // Volumetric Efficiency Progress Bar Layout
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.rtl,
              children: [
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'كفاءة سعة التعبئة الحجمية: ${_simulationResult!.efficiencyPercentage}%',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${_simulationResult!.usedVolumeCbm} / ${_simulationResult!.totalVolumeCbm} CBM',
                      style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _simulationResult!.efficiencyPercentage / 100,
                    backgroundColor: const Color(0xFF111827),
                    color: _simulationResult!.efficiencyPercentage > 85 ? Colors.redAccent : const Color(0xFF0D9488),
                    minHeight: 10,
                  ),
                ),
              ],
            ),
            const Divider(color: Color(0xFF374151), height: 32),

            // Metrics Summary Grid Row
            Row(
              textDirection: TextDirection.rtl,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryMetric(
                  'التكلفة الإجمالية الواصلة',
                  '${_simulationResult!.totalLandedCost} ${_simulationResult!.currency}',
                  goldAccent,
                ),
                _buildSummaryMetric(
                  'المساحة المتبقية (صندوق مقدر)',
                  '${_simulationResult!.remainingBoxCapacity} كرتون',
                  const Color(0xFF0D9488),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Re-simulate action trigger button
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: goldAccent,
                  side: const BorderSide(color: goldAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _runSimulation,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('تحديث وتحديث حساب التكاليف الخطية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputField({required String label, required TextEditingController controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF4B5563)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: TextDirection.rtl,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
