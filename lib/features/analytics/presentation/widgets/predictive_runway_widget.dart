import 'package:flutter/material.dart';
import '../../data/models/cash_flow_prediction_model.dart';
import '../../data/repositories/prediction_repository_factory.dart';

class PredictiveRunwayWidget extends StatefulWidget {
  const PredictiveRunwayWidget({super.key});

  @override
  State<PredictiveRunwayWidget> createState() => _PredictiveRunwayWidgetState();
}

class _PredictiveRunwayWidgetState extends State<PredictiveRunwayWidget> {
  final _repository = PredictionRepositoryFactory.make();
  int _runwayDays = 0;
  bool _isLoadingRunway = true;

  @override
  void initState() {
    super.initState();
    _loadRunwayDays();
  }

  Future<void> _loadRunwayDays() async {
    try {
      final days = await _repository.calculateCashRunwayDays();
      setState(() {
        _runwayDays = days;
        _isLoadingRunway = false;
      });
    } catch (_) {
      setState(() => _isLoadingRunway = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const goldAccent = Color(0xFFD4AF37); // Matte Gold

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      textDirection: TextDirection.rtl,
      children: [
        // Safe Cash Runway Header Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: goldAccent.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: goldAccent.withValues(alpha: 0.05),
                blurRadius: 15,
                spreadRadius: 1,
              )
            ],
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                textDirection: TextDirection.rtl,
                children: [
                  Text(
                    'الرصيد الزمني الآمن (Cash Runway)',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'الوقت المتوقع لمقاومة النفقات بناءً على معدل الحرق الحالي.',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                  ),
                ],
              ),
              _isLoadingRunway
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: goldAccent, strokeWidth: 2))
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: goldAccent),
                      ),
                      child: Text(
                        '$_runwayDays يومًا',
                        style: const TextStyle(color: goldAccent, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 90-Day Predictive Inflow/Outflow Timeline
        const Text(
          'المحاكاة الإحصائية للتدفقات النقدية المستقبلية (90 يوماً):',
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 12),

        StreamBuilder<List<CashFlowPredictionModel>>(
          stream: _repository.getRunwayForecast(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: CircularProgressIndicator(color: goldAccent)),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('لا توجد بيانات محاكاة متاحة حالياً.', style: TextStyle(color: Color(0xFF9CA3AF))),
              );
            }

            final forecasts = snapshot.data!;

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: forecasts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = forecasts[index];
                final isRiskHigh = item.riskProbability > 0.5;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isRiskHigh ? Colors.redAccent.withValues(alpha: 0.4) : const Color(0xFF374151),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textDirection: TextDirection.rtl,
                    children: [
                      Row(
                        textDirection: TextDirection.rtl,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'توقعات شهر: ${item.targetDate.month} / ${item.targetDate.year}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          if (isRiskHigh)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.redAccent),
                              ),
                              child: const Text('مخاطر سيولة مرتفعة', style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                            ),
                        ],
                      ),
                      const Divider(color: Color(0xFF374151), height: 24),
                      Row(
                        textDirection: TextDirection.rtl,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMetricColumn('المتحصلات المتوقعة', '+${item.expectedInflow} ر.س', const Color(0xFF0D9488)),
                          _buildMetricColumn('المصاريف المتوقعة', '-${item.expectedOutflow} ر.س', Colors.redAccent),
                          _buildMetricColumn('صافي المركز المالي', '${item.netLiquidityPosition} ر.س', goldAccent),
                        ],
                      ),
                      if (item.riskAlerts.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...item.riskAlerts.map((alert) => Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      alert,
                                      style: const TextStyle(color: Colors.amber, fontSize: 12),
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ]
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildMetricColumn(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: TextDirection.rtl,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
