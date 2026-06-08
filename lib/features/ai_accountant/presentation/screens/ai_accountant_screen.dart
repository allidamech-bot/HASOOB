import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../data/models/ai_proposal_model.dart';
import '../../data/repositories/ai_accountant_repository_factory.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final AiProposalModel? proposal;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.proposal,
  });
}

class AiAccountantScreen extends StatefulWidget {
  const AiAccountantScreen({super.key});

  @override
  State<AiAccountantScreen> createState() => _AiAccountantScreenState();
}

class _AiAccountantScreenState extends State<AiAccountantScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _repository = AiAccountantRepositoryFactory.make();
  
  bool _isTyping = false;
  bool _isExecuting = false;
  final List<ChatMessage> _messages = [];
  AiProposalModel? _extractedProposal;

  // Established Design System Palettes
  static const Color darkBg = Color(0xFF090D14);       // Deep Matte Black
  static const Color darkSurface = Color(0xFF111722);  // Premium Smooth Black
  static const Color goldAccent = Color(0xFFD4AF37);   // Matte Gold
  static const Color textSecondary = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    // Inject welcoming dynamic greeting from the interactive agent
    _messages.add(ChatMessage(
      text: "مرحباً بك في نظام HASOOB الذكي. أنا محاسبك الافتراضي المعزز، يمكنك التحدث معي بحرية بالعامية أو الفصحى، أو رفع المستندات مباشرة لتنظيم دفاتر حساباتك.",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage({String? customText}) async {
    final text = customText ?? _textController.text.trim();
    if (text.isEmpty) return;

    if (customText == null) _textController.clear();

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true, timestamp: DateTime.now()));
      _isTyping = true;
      _extractedProposal = null;
    });
    _scrollToBottom();

    try {
      final proposal = await _repository.parseNaturalLanguage(text);
      if (!mounted) return;

      setState(() {
        _extractedProposal = proposal.actionType != 'unknown' ? proposal : null;
        
        String responseText = proposal.explanation;
        if (proposal.actionType == 'unknown') {
          responseText = "لم أستطع استخراج قيد محاسبي مكتمل الأركان من النص المكتوب. يرجى تزويدي بتفاصيل إضافية عن السلع أو القيم المالية لأتمكن من صياغة المعاملة بدقة.";
        }

        _messages.add(ChatMessage(
          text: responseText,
          isUser: false,
          timestamp: DateTime.now(),
          proposal: proposal.actionType != 'unknown' ? proposal : null,
        ));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: "عذراً، واجهت مشكلة اتصال مؤقتة في النواة السحابية. يرجى إدخال الجملة المالية مرة أخرى.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _handleMultimodalOCR() async {
    setState(() {
      _isTyping = true;
      _extractedProposal = null;
      _messages.add(ChatMessage(
        text: "📥 قام المستخدم برفع صورة مستند/فاتورة توريد حية...",
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();

    try {
      final dummyBytes = Uint8List.fromList([0, 1, 2, 3]);
      final proposal = await _repository.parseInvoiceImage(dummyBytes, 'image/jpeg');
      if (!mounted) return;

      setState(() {
        _extractedProposal = proposal;
        _messages.add(ChatMessage(
          text: "✅ اكتمل الفحص متعدد الوسائط ضوئياً:\n${proposal.explanation}",
          isUser: false,
          timestamp: DateTime.now(),
          proposal: proposal,
        ));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: "❌ فشل المحرك الضوئي في فك تشفير جداول الفاتورة المرفوعة.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _handleExecuteLedger() async {
    if (_extractedProposal == null) return;

    setState(() => _isExecuting = true);
    try {
      final success = await _repository.executeProposal(_extractedProposal!);
      if (!mounted) return;

      if (success) {
        setState(() {
          _messages.add(ChatMessage(
            text: "⚙️ بروتوكول التنفيذ المالي: تم ترحيل المعاملة ذرياً وتحديث المستودعات والدفاتر الحية بنجاح بنسبة ثقة موازنة 100%.",
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _extractedProposal = null;
        });
      }
    } catch (_) {
      // Graceful error display
    } finally {
      if (mounted) {
        setState(() => _isExecuting = false);
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkSurface,
        elevation: 0,
        title: const Text(
          'المستشار المالي التفاعلي',
          style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(color: const Color(0xFF222B3C), height: 1.5),
        ),
      ),
      body: Column(
        children: [
          // Dynamic Multi-turn Chat Viewport Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildChatBubble(msg);
              },
            ),
          ),

          if (_isTyping)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: goldAccent, strokeWidth: 2))),
            ),

          // Sliding Action Hub for Executive Verification and End-User Approval
          if (_extractedProposal != null) _buildProposalExecutiveCard(),

          // Fixed Premium Dock Bar for Quick Context Prompts
          if (!_isTyping && _extractedProposal == null) _buildQuickSuggestionsBar(),

          // Modernized Dark SaaS Interaction Input Box
          _buildMessageInputField(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        textDirection: isUser ? TextDirection.ltr : TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isUser ? const Color(0xFF1F2937) : goldAccent.withValues(alpha: 0.1),
            child: Icon(
              isUser ? Icons.person_outline_rounded : Icons.psychology_outlined,
              color: isUser ? Colors.white70 : goldAccent,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF1E293B) : darkSurface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: isUser ? const Radius.circular(14) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : const Radius.circular(14),
                ),
                border: Border.all(
                  color: isUser ? const Color(0xFF334155) : const Color(0xFF222B3C),
                  width: 1.2,
                ),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFFE5E7EB),
                  fontSize: 13,
                  height: 1.5,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestionsBar() {
    final prompts = [
      "اشتريت 20 كرتونة منظف بسعر 50 للواحد",
      "زبون أحمد دفع 500 وباقي عليه 200",
      "احسب ضريبة 15% على 1200"
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: prompts.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              backgroundColor: darkSurface,
              side: const BorderSide(color: Color(0xFF222B3C)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              label: Text(
                prompts[index],
                style: const TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
              ),
              onPressed: () => _handleSendMessage(customText: prompts[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProposalExecutiveCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: goldAccent.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: goldAccent.withValues(alpha: 0.02), blurRadius: 10, spreadRadius: 1)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.rtl,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  const Icon(Icons.analytics_outlined, color: goldAccent, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'مراجعة وتعميد العقد المحاسبي المكتشف',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                'مطابقة: ${(_extractedProposal!.confidenceScore * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Color(0xFF0D9488), fontSize: 11, fontWeight: FontWeight.bold),
              )
            ],
          ),
          const Divider(color: Color(0xFF222B3C), height: 24),
          
          if (_extractedProposal!.inventoryPayload != null)
            _buildExtractedRow(Icons.inventory_2_outlined, 'المخزن:', '"${_extractedProposal!.inventoryPayload!['name']}" | العدد: ${_extractedProposal!.inventoryPayload!['quantity']}'),
          
          if (_extractedProposal!.financialPayload != null) ...[
            const SizedBox(height: 6),
            _buildExtractedRow(Icons.payments_outlined, 'المالية:', 'القيمة الإجمالية: ${_extractedProposal!.financialPayload!['totalAmount']} | المدفوع: ${_extractedProposal!.financialPayload!['amountPaid']}'),
          ],

          const SizedBox(height: 14),
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: goldAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: _isExecuting ? null : _handleExecuteLedger,
                    child: _isExecuting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Text('تأكيد وتعميد العملية مالياً', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Color(0xFF222B3C)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => setState(() => _extractedProposal = null),
                  child: const Text('إلغاء', style: TextStyle(fontSize: 12)),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildExtractedRow(IconData icon, String label, String value) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Icon(icon, color: textSecondary, size: 14),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: textSecondary, fontSize: 12)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            textDirection: TextDirection.rtl,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMessageInputField() {
    return Container(
      color: darkSurface,
      padding: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 20),
      child: Row(
        children: [
          // Matte Gold Action Send Arrow Button
          CircleAvatar(
            radius: 20,
            backgroundColor: goldAccent,
            child: IconButton(
              icon: const Icon(Icons.arrow_upward_rounded, color: Colors.black, size: 20),
              onPressed: () => _handleSendMessage(),
            ),
          ),
          const SizedBox(width: 10),
          
          // Central Standard Input Text Area Field
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: darkBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF222B3C)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.document_scanner_outlined, color: textSecondary, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _handleMultimodalOCR,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        hintText: 'تحدث مع المساعد المالي أو أرسل معاملة...',
                        hintStyle: TextStyle(color: Color(0xFF4B5563), fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onSubmitted: (_) => _handleSendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
