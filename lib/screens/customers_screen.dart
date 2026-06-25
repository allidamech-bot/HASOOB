import 'package:flutter/material.dart';

import '../core/app_copy.dart';
import '../core/app_messages.dart';
import '../core/app_theme.dart';
import '../core/business/business_context.dart';
import '../core/ui/responsive.dart';
import '../data/repositories/customer_repository.dart';
import '../core/utils/perf_logger.dart';
import '../widgets/skeleton_loader.dart';
import 'package:hasoob_app/widgets/premium/premium_card.dart';
import 'package:hasoob_app/screens/customer_statement_screen.dart';
import 'package:hasoob_app/screens/collection_center_screen.dart';
import 'package:hasoob_app/screens/documents_screen.dart';
import '../core/app_formatters.dart';
import '../widgets/ai_design_system.dart';
import '../features/customers/data/models/customer_model.dart';
import '../features/customers/data/repositories/customer_repository_factory.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final CustomerRepository _customerRepository = CustomerRepository();
  final _newCustomerRepository = CustomerRepositoryFactory.make();

  String get _businessId => BusinessContext.businessId;

  @override
  void initState() {
    super.initState();
    PerfLogger.logPageOpen('Customers');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PerfLogger.logFirstRender('Customers');
    });
  }

  Future<void> _refresh() async {
    await _customerRepository.getCustomers(_businessId);
  }

  Future<void> _openCustomerForm([Map<String, dynamic>? customer]) async {
    final copy = AppCopy.of(context);
    final nameController =
        TextEditingController(text: customer?['name']?.toString() ?? '');
    final phoneController =
        TextEditingController(text: customer?['phone']?.toString() ?? '');
    final notesController =
        TextEditingController(text: customer?['notes']?.toString() ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          customer == null
              ? copy.t('addCustomerTitle')
              : copy.t('editCustomerTitle'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: copy.t('addCustomer')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(labelText: copy.t('phone')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: copy.t('addressOrNotes'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(copy.t('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _customerRepository.saveCustomer(_businessId, {
                  'id': customer?['id'],
                  'name': nameController.text,
                  'phone': phoneController.text,
                  'notes': notesController.text,
                  'created_at': customer?['created_at'],
                });
                if (!context.mounted) return;
                Navigator.pop(context, true);
              } catch (error) {
                if (!context.mounted) return;
                AppMessages.error(context, '$error');
              }
            },
            child: Text(copy.t('save')),
          ),
        ],
      ),
    );

    nameController.dispose();
    phoneController.dispose();
    notesController.dispose();

    if (saved == true && mounted) {
      AppMessages.success(
        context,
        customer == null ? copy.t('customerAdded') : copy.t('customerUpdated'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(copy.t('customersTitle')),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CollectionCenterScreen()));
            },
            icon: const Icon(Icons.account_balance_wallet_rounded,
                color: AppTheme.aiGold),
            tooltip: copy.t('collectionCenterTitle'),
          ),
          IconButton(
            onPressed: () => _openCustomerForm(),
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCustomerForm(),
        icon: const Icon(Icons.add_rounded),
        label: Text(copy.t('newCustomer')),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _customerRepository.watchCustomers(_businessId),
          builder: (context, snapshot) {
            final hasData = snapshot.hasData && snapshot.data != null;

            if (snapshot.hasError && !hasData) {
              return _buildErrorState(context, copy, snapshot.error);
            }

            if (!hasData &&
                snapshot.connectionState == ConnectionState.waiting) {
              return _buildSkeleton(context, copy);
            }

            if (hasData) {
              PerfLogger.logDataLoaded('Customers');
            }

            final customers = snapshot.data ?? const <Map<String, dynamic>>[];

            if (customers.isEmpty &&
                snapshot.connectionState != ConnectionState.waiting) {
              return _buildEmptyState(context, copy);
            }

            final isDesktop = UIResponsive.isDesktop(context);
            return isDesktop
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children:
                        _buildContentList(context, copy, customers, isDesktop),
                  )
                : AiMobilePageShell(
                    child: Column(
                      children: [
                        const SizedBox(height: AiMobileConfig.sectionGap),
                        ..._buildContentList(
                            context, copy, customers, isDesktop),
                      ],
                    ),
                  );
          },
        ),
      ),
    );
  }

  List<Widget> _buildContentList(BuildContext context, AppCopy copy,
      List<Map<String, dynamic>> customers, bool isDesktop) {
    return [
      if (isDesktop) ...[
        _buildTopActionRow(context, copy, customers),
        _buildCollectionCenterCard(context, copy),
      ] else ...[
        _buildMobileTopActions(context, copy, customers),
      ],
      ...customers.map((customer) {
        final name = customer['name']?.toString() ?? '';
        final phone = customer['phone']?.toString() ?? '';
        final notes = customer['notes']?.toString().trim() ?? '';
        final outstanding = _toDouble(customer['outstanding_balance']);

        return Padding(
          padding: EdgeInsets.only(
            bottom: 12,
            left: isDesktop ? 0 : AiMobileConfig.horizontalPadding,
            right: isDesktop ? 0 : AiMobileConfig.horizontalPadding,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(
                isDesktop ? AppTheme.radiusLarge : AiMobileConfig.cardRadius),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerStatementScreen(
                    customerId: customer['id'].toString(),
                    customerName: name,
                  ),
                ),
              );
            },
            child: isDesktop
                ? PremiumCard(
                    padding: const EdgeInsets.all(20),
                    child: _customerRowContent(context, copy, customer, name,
                        phone, notes, outstanding),
                  )
                : AiGlassCard(
                    borderRadius: AiMobileConfig.cardRadius,
                    padding: const EdgeInsets.all(AiMobileConfig.cardPadding),
                    child: _customerRowContent(context, copy, customer, name,
                        phone, notes, outstanding),
                  ),
          ),
        );
      }),
      if (isDesktop) const SizedBox(height: 24),

      // ── Customers Data Layer Section (CustomerRepositoryFactory) ──────────
      if (isDesktop)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              copy.isEnglish
                  ? 'Additional Customer Catalog'
                  : 'دليل العملاء — طبقة النطاق',
              style: const TextStyle(
                color: AppTheme.aiBlue,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        )
      else
        AiMobileSectionHeader(
          title:
              copy.isEnglish ? 'Additional Customer Catalog' : 'دليل العملاء',
        ),

      Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 0 : AiMobileConfig.horizontalPadding,
        ),
        child: Text(
          copy.isEnglish
              ? 'This section shows customer records from the newer customer data layer. It may overlap with the main list while both data paths are active.'
              : 'يعرض هذا القسم سجلات العملاء من طبقة بيانات العملاء الأحدث، وقد يتداخل مع القائمة الرئيسية أثناء عمل المسارين.',
          style: const TextStyle(
            color: AppTheme.aiTextSecondary,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ),

      SizedBox(height: isDesktop ? 16 : AiMobileConfig.sectionGap),

      StreamBuilder<List<CustomerModel>>(
        stream: _newCustomerRepository.getCustomers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(context, copy, snapshot.error);
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: CircularProgressIndicator(color: AppTheme.aiBlue)),
            );
          }
          final customers = snapshot.data ?? const <CustomerModel>[];
          if (customers.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 0 : AiMobileConfig.horizontalPadding,
              ),
              child: AiGlassCard(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    copy.isEnglish
                        ? 'No additional customer records found.'
                        : 'لا يوجد عملاء.',
                    style: const TextStyle(
                      color: AppTheme.aiTextSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }
          return Column(
            children: customers
                .map((c) => Padding(
                      padding: EdgeInsets.only(
                        bottom: 12,
                        left: isDesktop ? 0 : AiMobileConfig.horizontalPadding,
                        right: isDesktop ? 0 : AiMobileConfig.horizontalPadding,
                      ),
                      child: _customerModelCard(c, copy, isDesktop),
                    ))
                .toList(),
          );
        },
      ),

      if (isDesktop) const SizedBox(height: 120),
    ];
  }

  Widget _customerRowContent(
      BuildContext context,
      AppCopy copy,
      Map<String, dynamic> customer,
      String name,
      String phone,
      String notes,
      double outstanding) {
    final displayName = name.trim().isEmpty
        ? (copy.isEnglish ? 'Unnamed customer' : 'عميل بدون اسم')
        : name.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.accent.withValues(alpha: 0.14),
          child: Text(
            displayName.substring(0, 1),
            style: const TextStyle(
              color: AppTheme.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _customerInfoChip(
                    icon: Icons.phone_outlined,
                    label: phone.trim().isEmpty
                        ? (copy.isEnglish ? 'No phone yet' : 'لا يوجد رقم بعد')
                        : phone.trim(),
                  ),
                  _customerInfoChip(
                    icon: Icons.account_balance_wallet_outlined,
                    label: copy.isEnglish
                        ? 'Outstanding ${AppFormatters.currency(outstanding)}'
                        : 'المستحق ${AppFormatters.currency(outstanding)}',
                    color: outstanding > 0 ? AppTheme.aiGold : AppTheme.aiGreen,
                  ),
                ],
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  notes,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textSecondaryFor(context),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: () => _openCustomerForm(customer),
          icon: const Icon(Icons.edit_outlined),
        ),
        const Icon(Icons.arrow_forward_ios_rounded,
            size: 16, color: AppTheme.aiTextSecondary),
      ],
    );
  }

  Widget _customerInfoChip({
    required IconData icon,
    required String label,
    Color color = AppTheme.aiTextSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTopActions(BuildContext context, AppCopy copy,
      List<Map<String, dynamic>> customers) {
    final double totalOutstanding = customers.fold<double>(
        0.0, (sum, c) => sum + _toDouble(c['outstanding_balance']));

    return Padding(
      padding: const EdgeInsets.only(bottom: AiMobileConfig.sectionGap),
      child: Column(
        children: [
          AiMobileKpiStrip(
            children: [
              AiMobileKpiChip(
                label:
                    '${copy.isEnglish ? 'Outstanding:' : 'إجمالي المستحقات:'} ${AppFormatters.currency(totalOutstanding)}',
                icon: Icons.account_balance_wallet_rounded,
                color: AppTheme.aiGold,
              ),
            ],
          ),
          const SizedBox(height: AiMobileConfig.sectionGap),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AiMobileConfig.horizontalPadding),
            child: Row(
              children: [
                AiMobileActionCard(
                  title: copy.isEnglish ? 'Collection Center' : 'مركز التحصيل',
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppTheme.aiRed,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CollectionCenterScreen())),
                ),
                const SizedBox(width: 12),
                AiMobileActionCard(
                  title: copy.isEnglish ? 'Sales Operation' : 'عملية مبيعات',
                  icon: Icons.add_shopping_cart,
                  color: AppTheme.aiBlue,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DocumentsScreen())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context, AppCopy copy) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(5, (index) => const SkeletonListTile()),
    );
  }

  Widget _buildErrorState(BuildContext context, AppCopy copy, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppTheme.danger, size: 48),
            const SizedBox(height: 16),
            Text(
              copy.t('loadCustomersError'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(copy.t('retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppCopy copy) {
    final isDesktop = UIResponsive.isDesktop(context);
    if (!isDesktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AiMobileConfig.horizontalPadding),
        child: AiMobileEmptyState(
          title: copy.t('noCustomersYet'),
          subtitle: copy.isEnglish
              ? 'Start tracking your clients.'
              : 'لا توجد بيانات عملاء مسجلة حالياً.',
          icon: Icons.people_outline_rounded,
          actionLabel: copy.t('newCustomer'),
          onAction: () => _openCustomerForm(),
        ),
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.people_outline_rounded,
            size: 48, color: AppTheme.accent),
        const SizedBox(height: 16),
        Center(
          child: Text(
            copy.t('noCustomersYet'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              copy.isEnglish
                  ? 'Create a customer before issuing invoices or tracking outstanding balances. Add phone and notes now, then open the statement later.'
                  : 'أنشئ عميلا قبل إصدار الفواتير أو متابعة الأرصدة المستحقة. أضف الهاتف والملاحظات الآن ثم افتح الكشف لاحقا.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.aiTextSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            onPressed: () => _openCustomerForm(),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(copy.t('newCustomer')),
          ),
        ),
      ],
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _buildTopActionRow(BuildContext context, AppCopy copy,
      List<Map<String, dynamic>> customers) {
    final double totalOutstanding = customers.fold<double>(
        0.0, (sum, c) => sum + _toDouble(c['outstanding_balance']));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.aiCardElevated,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.aiGold.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إجمالي المستحقات',
                      style: TextStyle(
                          color: AppTheme.aiTextSecondary, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(AppFormatters.currency(totalOutstanding),
                      style: const TextStyle(
                          color: AppTheme.aiGold,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DocumentsScreen()));
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.aiBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_shopping_cart, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('عملية مبيعات',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCenterCard(BuildContext context, AppCopy copy) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AiGlassCard(
        padding: const EdgeInsets.all(16),
        borderColor: AppTheme.aiGold.withValues(alpha: 0.4),
        glowColor: AppTheme.aiGold,
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CollectionCenterScreen()));
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.aiGold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: AppTheme.aiGold, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.t('collectionCenterTitle'),
                    style: const TextStyle(
                      color: AppTheme.aiTextPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'تابع الفواتير المتأخرة ومخاطر العملاء ورسائل التذكير',
                    style: TextStyle(
                      color: AppTheme.aiTextSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppTheme.aiGold, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _customerModelCard(
      CustomerModel customer, AppCopy copy, bool isDesktop) {
    final isActive = customer.status == 'active';
    final statusColor = isActive ? AppTheme.aiGreen : AppTheme.aiRed;
    final statusLabel = isActive
        ? (copy.isEnglish ? 'Active' : 'نشط')
        : (copy.isEnglish ? 'Inactive' : 'غير نشط');

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      border: Border.all(
        color: statusColor.withValues(alpha: 0.2),
        width: 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: statusColor.withValues(alpha: 0.14),
                child: Text(
                  customer.name.isEmpty ? '?' : customer.name.substring(0, 1),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppTheme.aiTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer.phone.isNotEmpty
                          ? customer.phone
                          : (copy.isEnglish ? 'No phone' : 'بدون رقم'),
                      style: const TextStyle(
                        color: AppTheme.aiTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: statusColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          if (customer.email.isNotEmpty || customer.address.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (customer.email.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.email_outlined,
                      size: 14, color: AppTheme.aiTextSecondary),
                  const SizedBox(width: 8),
                  Text(customer.email,
                      style: const TextStyle(
                          color: AppTheme.aiTextSecondary, fontSize: 12)),
                ],
              ),
            if (customer.address.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppTheme.aiTextSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(customer.address,
                            style: const TextStyle(
                                color: AppTheme.aiTextSecondary,
                                fontSize: 12))),
                  ],
                ),
              ),
          ],
          if (customer.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: customer.tags
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.aiBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.aiBlue.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          '#$tag',
                          style: const TextStyle(
                              color: AppTheme.aiBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
