import 'package:flutter/material.dart';
import '../models/ai_thread.dart';
import '../models/ai_message.dart';
import '../models/ai_action_draft.dart';
import '../services/ai_copilot_service.dart';
import '../services/ai_action_planner.dart';
import '../repositories/ai_copilot_repository.dart';

class AiCopilotScreen extends StatefulWidget {
  final String businessId;
  final String userId;

  const AiCopilotScreen({
    super.key,
    required this.businessId,
    required this.userId,
  });

  @override
  State<AiCopilotScreen> createState() => _AiCopilotScreenState();
}

class _AiCopilotScreenState extends State<AiCopilotScreen> {
  late AiCopilotService _service;
  final TextEditingController _textController = TextEditingController();
  
  AiThread? _currentThread;
  List<AiMessage> _messages = [];
  AiActionDraft? _currentDraft;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // In a real app this would use DI (e.g., GetIt or Provider)
    final repo = AiCopilotRepository();
    final planner = AiActionPlanner();
    _service = AiCopilotService(repo, planner);
    _initThread();
  }

  Future<void> _initThread() async {
    setState(() => _isLoading = true);
    final thread = await _service.startOrLoadThread(widget.businessId, widget.userId);
    final messages = await _service.getThreadMessages(thread.id);
    final draft = await _service.getLatestDraft(widget.businessId);
    
    setState(() {
      _currentThread = thread;
      _messages = messages;
      _currentDraft = draft;
      _isLoading = false;
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _currentThread == null) return;

    _textController.clear();
    await _service.sendUserMessage(text, _currentThread!);
    
    final messages = await _service.getThreadMessages(_currentThread!.id);
    final draft = await _service.getLatestDraft(widget.businessId);

    setState(() {
      _messages = messages;
      _currentDraft = draft;
    });
  }

  Future<void> _confirmDraft() async {
    if (_currentDraft == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تنفيذ العمليات التجارية غير مفعل في هذه المرحلة'),
        backgroundColor: Colors.orange,
      ),
    );

    await _service.confirmDraft(_currentDraft!.id);
    final draft = await _service.getLatestDraft(widget.businessId);
    
    setState(() {
      _currentDraft = draft;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Copilot Foundation'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg.role == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.blue.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(msg.content),
                      ),
                    );
                  },
                ),
              ),
              if (_currentDraft != null) _buildDraftCard(),
              _buildComposer(),
            ],
          ),
    );
  }

  Widget _buildDraftCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentDraft!.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_currentDraft!.summary),
          const SizedBox(height: 8),
          const Text(
            'مسودة فقط — لن يتم الحفظ قبل التأكيد',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _confirmDraft,
            child: const Text('Confirm (Simulated)'),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Ask Copilot...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            color: Colors.blue,
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
