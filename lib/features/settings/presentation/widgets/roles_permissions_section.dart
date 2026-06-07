import 'package:flutter/material.dart';
import '../../data/models/user_settings_model.dart';
import '../../data/repositories/settings_repository_factory.dart';

class RolesPermissionsSection extends StatefulWidget {
  const RolesPermissionsSection({super.key});

  @override
  State<RolesPermissionsSection> createState() => _RolesPermissionsSectionState();
}

class _RolesPermissionsSectionState extends State<RolesPermissionsSection> {
  final _repository = SettingsRepositoryFactory.make();
  final String _defaultEmail = 'owner@hasoob.com';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserSettingsModel>(
      stream: _repository.getUserSettings(_defaultEmail),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0D9488)));
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Text('خطأ في تحميل إعدادات الصلاحيات', style: TextStyle(color: Colors.redAccent)),
          );
        }

        final settings = snapshot.data!;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937), // Dark Card Background
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF374151), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.rtl,
            children: [
              const Text(
                'إدارة الأدوار والصلاحيات',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 4),
              const Text(
                'تخصيص الصلاحيات الوظيفية والمستوى الأمني لحساب المستخدم الحالي.',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 24),

              // Role Selection Row
              Row(
                textDirection: TextDirection.rtl,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الدور الوظيفي المخصص:',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF4B5563)),
                    ),
                    child: DropdownButton<String>(
                      value: settings.role,
                      dropdownColor: const Color(0xFF111827),
                      underline: const SizedBox(),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF9CA3AF)),
                      items: const [
                        DropdownMenuItem(value: 'owner', child: Text('مالك النظام (Owner)')),
                        DropdownMenuItem(value: 'manager', child: Text('مدير عمليات (Manager)')),
                        DropdownMenuItem(value: 'employee', child: Text('موظف (Employee)')),
                      ],
                      onChanged: (newRole) {
                        if (newRole != null) {
                          _repository.updateUserSettings(
                            UserSettingsModel(
                              email: settings.email,
                              role: newRole,
                              permissions: settings.permissions,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Color(0xFF374151)),
              ),

              // Permissions List Headers
              const Text(
                'قائمة التحكم بالصلاحيات تفصيلياً:',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 16),

              // Permission Toggles
              _buildPermissionToggle(
                title: 'تعديل وتحديث المخزون وعناصر المنتجات',
                key: 'canEditInventory',
                currentValue: settings.permissions['canEditInventory'] ?? false,
                settings: settings,
              ),
              _buildPermissionToggle(
                title: 'عرض محرك التقارير والتحليلات المالية المتقدمة',
                key: 'canViewReports',
                currentValue: settings.permissions['canViewReports'] ?? false,
                settings: settings,
              ),
              _buildPermissionToggle(
                title: 'إدارة وإصدار الفواتير وسندات التحصيل المالي',
                key: 'canManageInvoices',
                currentValue: settings.permissions['canManageInvoices'] ?? false,
                settings: settings,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPermissionToggle({
    required String title,
    required String key,
    required bool currentValue,
    required UserSettingsModel settings,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
              textDirection: TextDirection.rtl,
            ),
          ),
          Switch(
            value: currentValue,
            activeThumbColor: const Color(0xFF0D9488),
            activeTrackColor: const Color(0xFF0D9488).withValues(alpha: 0.3),
            inactiveThumbColor: const Color(0xFF9CA3AF),
            inactiveTrackColor: const Color(0xFF374151),
            onChanged: (newValue) {
              final updatedPermissions = Map<String, bool>.from(settings.permissions);
              updatedPermissions[key] = newValue;
              _repository.updateUserSettings(
                UserSettingsModel(
                  email: settings.email,
                  role: settings.role,
                  permissions: updatedPermissions,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
