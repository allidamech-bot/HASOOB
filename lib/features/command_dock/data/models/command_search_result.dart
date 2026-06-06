class CommandSearchResult {
  final String id;
  final String title;
  final String subtitle;
  final String type; // 'product' | 'customer' | 'invoice' | 'action'
  final String routePath;

  CommandSearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.routePath,
  });
}
