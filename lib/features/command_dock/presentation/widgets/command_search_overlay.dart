import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/command_search_result.dart';
import '../../data/repositories/command_dock_repository_factory.dart';

class CommandSearchOverlay extends StatefulWidget {
  const CommandSearchOverlay({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => const CommandSearchOverlay(),
    );
  }

  @override
  State<CommandSearchOverlay> createState() => _CommandSearchOverlayState();
}

class _CommandSearchOverlayState extends State<CommandSearchOverlay> {
  final _controller = TextEditingController();
  final _repository = CommandDockRepositoryFactory.make();
  String _query = '';
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'product': return Icons.inventory_2_outlined;
      case 'customer': return Icons.people_alt_outlined;
      case 'invoice': return Icons.receipt_long_outlined;
      case 'action': return Icons.bolt_rounded;
      default: return Icons.search_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'product': return const Color(0xFF0D9488); // Teal
      case 'customer': return const Color(0xFF2563EB); // Blue
      case 'invoice': return const Color(0xFFD97706); // Amber
      case 'action': return const Color(0xFF7C3AED); // Purple
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 64),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 650),
          decoration: BoxDecoration(
            color: const Color(0xFF111827), // Premium Dark
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF374151), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Input Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                key: const ValueKey('search_input_padding'),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textDirection: TextDirection.rtl,
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'ابحث عن منتج، عميل، فاتورة أو إجراء سريع...',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                    hintTextDirection: TextDirection.rtl,
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                    suffixIcon: _query.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Color(0xFF9CA3AF)),
                            onPressed: () {
                              _controller.clear();
                              setState(() { _query = ''; });
                            },
                          )
                        : Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F2937),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF4B5563)),
                            ),
                            child: const Text('ESC', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          ),
                    filled: true,
                    fillColor: const Color(0xFF1F2937),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
                    ),
                  ),
                ),
              ),
              const Divider(color: Color(0xFF374151), height: 1),

              // Results Section
              Flexible(
                child: StreamBuilder<List<CommandSearchResult>>(
                  stream: _repository.globalSearch(_query),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF0D9488))),
                      );
                    }

                    final results = snapshot.data ?? [];

                    if (results.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'لا توجد نتائج مطابقة لبحثك',
                          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                          textDirection: TextDirection.rtl,
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: results.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      separatorBuilder: (context, index) => const Divider(color: Color(0xFF1F2937), height: 1),
                      itemBuilder: (context, index) {
                        final item = results[index];
                        final typeColor = _getTypeColor(item.type);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_getTypeIcon(item.type), color: typeColor, size: 20),
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                            textDirection: TextDirection.rtl,
                          ),
                          subtitle: Text(
                            item.subtitle,
                            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                            textDirection: TextDirection.rtl,
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            // Trigger dynamic navigation via routePath
                            Navigator.of(context).pushNamed(item.routePath);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
