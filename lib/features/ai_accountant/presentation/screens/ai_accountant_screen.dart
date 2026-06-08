import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../data/models/ai_proposal_model.dart';
import '../../data/repositories/ai_accountant_repository_factory.dart';

class AiAccountantScreen extends StatefulWidget {
  const AiAccountantScreen({super.key});

  @override
  State<AiAccountantScreen> createState() => _AiAccountantScreenState();
}

class _AiAccountantScreenState extends State<AiAccountantScreen> {
  final _textController = TextEditingController();
  final _repository = AiAccountantRepositoryFactory.make();
  
  bool _isParsing = false;
  bool _isExecuting = false;
  AiProposalModel? _activeProposal;
  String? _errorMessage;
  
  bool _isImageUploaded = false;
  String? _uploadedFileName;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleParse() async {
    if (_textController.text.trim().isEmpty) return;

    setState(() {
      _isParsing = true;
      _activeProposal = null;
      _errorMessage = null;
    });

    try {
      final proposal = await _repository.parseNaturalLanguage(_textController.text);
      if (!mounted) return; // Production Guard Against Async Disposed States
      setState(() {
        _activeProposal = proposal;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'حدث خطأ أثناء تحليل النص، يرجى المحاولة مرة أخرى.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isParsing = false;
        });
      }
    }
  }

  Future<void> _handleImageUploadSimulation() async {
    setState(() {
      _isParsing = true;
      _activeProposal = null;
      _errorMessage = null;
      _isImageUploaded = true;
      _uploadedFileName = "INVOICE_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}.jpg";
    });

    try {
      final dummyBytes = Uint8List.fromList([0, 1, 2, 3]);
      final proposal = await _repository.parseInvoiceImage(dummyBytes, 'image/jpeg');
      if (!mounted) return; // Production Guard Against Async Disposed States
      setState(() {
        _activeProposal = proposal;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'فشل محرك OCR في قراءة تفاصيل الفاتورة المصورة.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isParsing = false;
        });
      }
    }
  }

  Future<void> _handleExecute() async {
    if (_activeProposal == null) return;

    setState(() {
      _isExecuting = true;
    });

    try {
      final success = await _repository.executeProposal(_activeProposal!);
      if (!mounted) return; // Production Guard
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تعميد القيد المحاسبي وترحيله بنجاح للدفاتر الحية!', textDirection: TextDirection.rtl),
            backgroundColor: Color(0xFF0D9488),
          ),
        );
        setState(() {
          _activeProposal = null;
          _textController.clear();
          _isImageUploaded = false;
          _uploadedFileName = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل ترحيل المعاملة المالية.', textDirection: TextDirection.rtl),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExecuting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const goldAccent = Color(0xFFD4AF37);
    const darkBg = Color(0xFF0B0F17);

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text(
          'المحاسب الذكي المعزز',
          style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF374151)),
              ),
              child: const Column(
                children: [
                  Text(
                    '🤖 النواة المحاسبية المستندة إلى الذكاء الاصطناعي',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    textDirection: TextDirection.rtl,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'اكتب المعاملات التجارية بالعامية أو الفصحى، أو قم برفع فواتير الشحن والموردين المصورة لترحيلها تلقائياً بلمسة واحدة للدفاتر.',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, height: 1.4),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _isParsing ? null : _handleImageUploadSimulation,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isImageUploaded ? const Color(0xFF0D9488) : goldAccent.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isImageUploaded ? Icons.task_alt_rounded : Icons.document_scanner_outlined,
                      color: _isImageUploaded ? const Color(0xFF0D9488) : goldAccent,
                      size: 36,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isImageUploaded ? 'تم رفع المستند بنجاح واكتشاف الحقول' : 'اسحب وأفلت فاتورة المورد أو انقر للتصوير المباشر',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    if (_isImageUploaded && _uploadedFileName != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _uploadedFileName!,
                        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(child: Divider(color: Color(0xFF374151))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('أو إدخال نصي سريع', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                ),
                Expanded(child: Divider(color: Color(0xFF374151))),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF4B5563)),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: _textController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      hintText: 'مثال: بعنا اليوم ٢ كرتون عصير لمؤسسة أحمد بقيمة ٨٠٠٠ ريال واستلمنا نصف المبلغ...',
                      hintStyle: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: goldAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isParsing ? null : _handleParse,
                      icon: _isParsing 
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : const Icon(Icons.psychology_outlined, size: 18),
                      label: const Text('تحليل النص المالي ذكياً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent))),
            if (_activeProposal != null) ...[
              const Text(
                'مسودة القيد المستخرجة للمراجعة والتعميد:',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: goldAccent.withValues(alpha: 0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: goldAccent.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: 2)
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  textDirection: TextDirection.rtl,
                  children: [
                    Row(
                      textDirection: TextDirection.rtl,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: goldAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: goldAccent),
                          ),
                          child: Text(
                            _activeProposal!.actionType.toUpperCase(),
                            style: const TextStyle(color: goldAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          'نسبة الثقة: ${(_activeProposal!.confidenceScore * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(color: Color(0xFF0D9488), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _activeProposal!.explanation,
                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                      textDirection: TextDirection.rtl,
                    ),
                    const Divider(color: Color(0xFF374151), height: 32),
                    if (_activeProposal!.inventoryPayload != null) ...[
                      _buildPayloadSummary(
                        icon: Icons.inventory_2_outlined,
                        title: 'تأثير المخازن والمستودعات:',
                        details: 'الصنف: "${_activeProposal!.inventoryPayload!['name']}" | الكمية: ${_activeProposal!.inventoryPayload!['quantity']}',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_activeProposal!.customerPayload != null) ...[
                      _buildPayloadSummary(
                        icon: Icons.people_outline,
                        title: 'أطراف المعاملة التجارية:',
                        details: 'الجهة/المؤسسة: ${_activeProposal!.customerPayload!['name']}',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_activeProposal!.financialPayload != null) ...[
                      _buildPayloadSummary(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'التسوية والترحيل المالي:',
                        details: 'القيمة الإجمالية: ${_activeProposal!.financialPayload!['totalAmount']} ر.س | المدفوع: ${_activeProposal!.financialPayload!['amountPaid']} ر.س',
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isExecuting ? null : _handleExecute,
                        child: _isExecuting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('تعميد وترحيل القيد آلياً للميزانية', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildPayloadSummary({required IconData icon, required String title, required String details}) {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF9CA3AF), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.rtl,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(details, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
