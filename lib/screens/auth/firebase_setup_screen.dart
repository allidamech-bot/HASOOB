import 'package:flutter/material.dart';

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B0B0B),
              Color(0xFF17130A),
              Color(0xFF241C08),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.settings_input_component_outlined,
                        size: 44,
                        color: Color(0xFFD4AF37),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'يلزم إعداد Firebase',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'تدفق المصادقة جاهز داخل التطبيق، لكن المشروع يحتاج إلى بيانات اعتماد Firebase الحقيقية حتى يعمل تسجيل الدخول.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'الخطوات المقترحة:',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. أنشئ مشروع Firebase وفعّل تسجيل الدخول بالبريد الإلكتروني وكلمة المرور.\n'
                        '2. سجّل تطبيق Windows أو Android أو iOS حسب بيئة التشغيل المطلوبة.\n'
                        '3. أضف ملفات الإعداد المناسبة للمشروع.\n'
                        '4. أعد بناء التطبيق ثم اختبر المصادقة.',
                      ),
                      const SizedBox(height: 16),
                      SelectableText(
                        message,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
