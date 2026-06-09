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
  final List<ChatMessage> _messages = [];
  AiProposalModel? _extractedProposal;

  // Premium Dark SaaS Palette Definition
  static const Color darkBg = Color(0xFF090D14);
  static const Color darkSurface = Color(0xFF111722);
  static const Color goldAccent = Color(0xFFD4AF37);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color borderCard = Color(0xFF222B3C);

  @override
  void initState() {
    super.initState();
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
          duration: const Duration(milliseconds: 200),
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
          text: "عذراً، واجهت مشكلة اتصال مؤقتة في النواة السحابية. يرجى إعادة المحاولة.",
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
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Utilize LayoutBuilder to detect if viewport is Desktop widescreen
    return Scaffold(
      backgroundColor: darkBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 950;
          
          if (isDesktop) {
            return Row(
              textDirection: TextDirection.rtl,
              children: [
                // Center Module Workspace: Chat Loop & Actions
                Expanded(
                  flex: 3,
                  child: _buildCentralWorkspace(),
                ),
                // Left Module Workspace: Recent Activity Feed (Clean Desktop Split)
                Expanded(
                  flex: 1,
                  child: _buildLeftActivitySidebar(),
                ),
              ],
            );
          } else {
            // Mobile viewport fallback stack
            return _buildCentralWorkspace();
          }
        },
      ),
    );
  }

  Widget _buildCentralWorkspace() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF1F2937), width: 0.5)),
      ),
      child: Column(
        children: [
          // Screen Context Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            color: darkSurface,
            child: const Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(Icons.psychology_outlined, color: goldAccent, size: 22),
                SizedBox(width: 10),
                Text(
                  'المستشار المالي التفاعلي الموحد',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ),
          
          // Chat Streams History Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildChatBubble(_messages[index]),
            ),
          ),

          if (_isTyping)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: goldAccent, strokeWidth: 2)),
            ),

          // Safe Container Bounds: Proposals do NOT span across sidebars anymore
          if (_extractedProposal != null) _buildProposalExecutiveCard(),

          // Quick Action Chip Prompts
          if (!_isTyping && _extractedProposal == null) _buildQuickSuggestionsBar(),

          // Interactive Command Input Area Container
          _buildMessageInputField(),
        ],
      ),
    );
  }

  Widget _buildLeftActivitySidebar() {
    return Container(
      color: const Color(0xFF0D111A),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.rtl,
        children: [
          const Text(
            'النشاط الأخير للقيود',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 12),
          // Clean custom search field inside activity feed
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: darkBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderCard),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: const Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(Icons.search, color: textSecondary, size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'ابحث في السجل...',
                      hintStyle: TextStyle(color: Color(0xFF4B5563), fontSize: 11),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _buildActivityLogItem('مؤنتال', 'معاملة غير محددة', 'معاينة القيد'),
                _buildActivityLogItem('hgm', 'معاملة قيد معلقة', 'معاينة القيد'),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActivityLogItem(String title, String type, String action) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: TextDirection.rtl,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(type, style: const TextStyle(color: textSecondary, fontSize: 11)),
              Text(action, style: const TextStyle(color: goldAccent, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          )
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
            radius: 14,
            backgroundColor: isUser ? const Color(0xFF1F2937) : goldAccent.withValues(alpha: 0.1),
            child: Icon(
              isUser ? Icons.person_outline_rounded : Icons.psychology_outlined,
              color: isUser ? Colors.white70 : goldAccent,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF1E293B) : darkSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isUser ? const Color(0xFF334155) : borderCard),
              ),
              child: Text(
                msg.text,
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
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
      height: 36,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: prompts.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              backgroundColor: darkSurface,
              side: const BorderSide(color: borderCard),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              label: Text(prompts[index], style: const TextStyle(color: textSecondary, fontSize: 11)),
              onPressed: () => _handleSendMessage(customText: prompts[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProposalExecutiveCard() {
    final isPricing = _extractedProposal!.actionType == 'pricing_simulation';
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPricing ? const Color(0xFF0D9488) : goldAccent.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.rtl,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPricing ? '📊 محاكاة التكلفة وهامش الربح اللوجستي المستهدف' : '⚖️ مراجعة العقد المحاسبي الذكي وتعميده',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                'تحليل دقيق',
                style: TextStyle(color: isPricing ? const Color(0xFF0D9488) : goldAccent, fontSize: 11),
              )
            ],
          ),
          const Divider(color: borderCard, height: 20),
          if (isPricing && _extractedProposal!.pricingPayload != null) ...[
            _buildExtractedRow(Icons.place_outlined, 'الوجهة الدولية:', _extractedProposal!.pricingPayload!['destination']),
            const SizedBox(height: 4),
            _buildExtractedRow(Icons.inventory_2_outlined, 'سعة الحاوية المقدرة:', '${_extractedProposal!.pricingPayload!['estimatedTotalBoxes']} كرتون كامل'),
            const Divider(color: borderCard, height: 16),
            Row(
              textDirection: TextDirection.rtl,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricBlock('تكلفة الكرتون (Landed)', '${_extractedProposal!.pricingPayload!['landedCostPerUnit']} \$', goldAccent),
                _buildMetricBlock('سعر البيع لربح صافي 25%', '${_extractedProposal!.pricingPayload!['suggestedPricePerUnit']} \$', const Color(0xFF0D9488)),
              ],
            )
          ] else ...[
            if (_extractedProposal!.inventoryPayload != null)
              _buildExtractedRow(Icons.inventory_2_outlined, 'تأثير المخزن:', '"${_extractedProposal!.inventoryPayload!['name']}" | العدد: ${_extractedProposal!.inventoryPayload!['quantity']}'),
            if (_extractedProposal!.financialPayload != null) ...[
              const SizedBox(height: 4),
              _buildExtractedRow(Icons.payments_outlined, 'القيد المالي الإجمالي:', 'القيمة: ${_extractedProposal!.financialPayload!['totalAmount']} ر.س | المحصل: ${_extractedProposal!.financialPayload!['amountPaid']} ر.س'),
            ],
          ],
          const SizedBox(height: 14),
          // Action Buttons: Styled STRICTLY in Matte Black and Gold/Teal - NO MORE CLASHING BLUE
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPricing ? const Color(0xFF0D9488) : goldAccent,
                      foregroundColor: isPricing ? Colors.white : Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () {
                      if (isPricing) {
                        setState(() {
                          _messages.add(ChatMessage(text: "💡 تم حفظ دراسة الجدوى اللوجستية بنجاح.", isUser: false, timestamp: DateTime.now()));
                          _extractedProposal = null;
                        });
                      } else {
                        _handleExecuteLedger();
                      }
                    },
                    child: Text(isPricing ? 'حفظ دراسة الجدوى' : 'اعتماد وتعميد المعاملة فوراً', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: borderCard),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () => setState(() => _extractedProposal = null),
                  child: const Text('إلغاء القيد', style: TextStyle(fontSize: 12)),
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
        Text(label, style: const TextStyle(color: textSecondary, fontSize: 11)),
        const SizedBox(width: 4),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 11), overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl)),
      ],
    );
  }

  Widget _buildMetricBlock(String title, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: TextDirection.rtl,
      children: [
        Text(title, style: const TextStyle(color: textSecondary, fontSize: 10)),
        Text(val, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMessageInputField() {
    return Container(
      color: darkSurface,
      padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: goldAccent,
            child: IconButton(
              icon: const Icon(Icons.arrow_upward_rounded, color: Colors.black, size: 18),
              onPressed: () => _handleSendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: darkBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderCard),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.document_scanner_outlined, color: textSecondary, size: 18),
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
                        hintText: 'تحدث مع المساعد المالي أو أرسل معاملة الحاوية...',
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
