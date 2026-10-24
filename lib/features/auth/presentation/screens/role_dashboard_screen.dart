import 'package:flutter/material.dart';

import '../../../../core/router/role_guard.dart';
import '../../../../core/theme/app_colors.dart';

/// Interactive mock-backed MVP workspaces for business and platform roles.
/// Mutations live for the current app session; production writes must go through
/// an authenticated backend enforcing the same role permissions.
class RoleDashboardScreen extends StatefulWidget {
  const RoleDashboardScreen({super.key, required this.role});
  final UserRole role;

  @override
  State<RoleDashboardScreen> createState() => _RoleDashboardScreenState();
}

class _RoleDashboardScreenState extends State<RoleDashboardScreen> {
  final _titleController = TextEditingController();
  final _detailController = TextEditingController();
  final _members = <_Record>[
    _Record('Nicha S.', 'nicha@acme.co', 'กำลังเรียน', true),
    _Record('Preecha K.', 'preecha@acme.co', 'รอมอบหมาย', true),
    _Record('Mali T.', 'mali@acme.co', 'เรียนจบ 2 คอร์ส', true),
  ];
  final _paths = <_Record>[
    _Record('Data literacy', '3 คอร์ส · 12 สัปดาห์', 'กำลังใช้งาน', true),
    _Record('Leadership essentials', '2 คอร์ส · 8 สัปดาห์', 'ฉบับร่าง', false),
  ];
  final _jobs = <_Record>[
    _Record('Product Designer', 'Bangkok · Hybrid', 'เปิดรับสมัคร', true),
    _Record('Flutter Developer', 'Remote · Full-time', 'เปิดรับสมัคร', true),
  ];
  final _candidates = <_Record>[
    _Record('Arthit W.', 'Product Designer', 'ใหม่', false),
    _Record('Pimchanok R.', 'Flutter Developer', 'สัมภาษณ์', true),
    _Record('Krit S.', 'Product Designer', 'ใหม่', false),
  ];
  final _platformUsers = <_Record>[
    _Record(
        'Somchai Instructor', 'ผู้สอน · somchai@demo.co', 'รอตรวจสอบ', false),
    _Record('Demo Learner', 'ผู้เรียน · learner@demo.co', 'ใช้งานอยู่', true),
    _Record('Pimchanok Employer', 'นายจ้าง · pim@demo.co', 'ใช้งานอยู่', true),
  ];
  final _courses = <_Record>[
    _Record('Flutter พื้นฐาน', 'Somchai Instructor · ส่งเมื่อวันนี้', 'รอตรวจ',
        false),
    _Record('UX Research', 'Nicha S. · ส่งเมื่อวาน', 'รอตรวจ', false),
  ];
  int _selectedTab = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec(widget.role);
    if (spec == null) {
      return const Scaffold(
          body: Center(child: Text('ไม่พบหน้าสำหรับสิทธิ์นี้')));
    }
    final tabs = spec.tabs;
    _selectedTab = _selectedTab.clamp(0, tabs.length - 1);
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text(spec.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
                child: Chip(
                    avatar: const Icon(Icons.verified_user_outlined, size: 17),
                    label: Text(spec.roleLabel))),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: ListView(
            padding: EdgeInsets.all(width < 600 ? 16 : 28),
            children: [
              _HeroPanel(spec: spec, count: _primaryCount(spec)),
              const SizedBox(height: 20),
              _metrics(spec),
              const SizedBox(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (var i = 0; i < tabs.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    ChoiceChip(
                        label: Text(tabs[i]),
                        selected: _selectedTab == i,
                        onSelected: (_) => setState(() => _selectedTab = i)),
                  ]
                ]),
              ),
              const SizedBox(height: 16),
              _content(spec),
            ],
          ),
        ),
      ),
      floatingActionButton: _actionFor(spec),
    );
  }

  int _primaryCount(_RoleSpec spec) => switch (widget.role) {
        UserRole.corporateAdmin || UserRole.corporateManager => _members.length,
        UserRole.employer => _jobs.where((e) => e.enabled).length,
        UserRole.admin => _courses.where((e) => !e.enabled).length,
        UserRole.superAdmin => _platformUsers.length,
        _ => 0,
      };

  Widget _metrics(_RoleSpec spec) {
    final values = switch (widget.role) {
      UserRole.corporateAdmin || UserRole.corporateManager => [
          ('สมาชิกทั้งหมด', '${_members.length}', Icons.groups_outlined),
          ('แผนการเรียน', '${_paths.length}', Icons.route_outlined),
          (
            'เรียนต่อเนื่อง',
            '${_members.where((e) => e.enabled).length}',
            Icons.trending_up
          ),
        ],
      UserRole.employer => [
          (
            'ตำแหน่งที่เปิด',
            '${_jobs.where((e) => e.enabled).length}',
            Icons.work_outline
          ),
          ('ผู้สมัคร', '${_candidates.length}', Icons.person_search_outlined),
          (
            'รอตรวจ',
            '${_candidates.where((e) => !e.enabled).length}',
            Icons.inbox_outlined
          ),
        ],
      UserRole.admin => [
          ('ผู้ใช้', '${_platformUsers.length}', Icons.people_outline),
          (
            'คอร์สรอตรวจ',
            '${_courses.where((e) => !e.enabled).length}',
            Icons.fact_check_outlined
          ),
          ('กิจกรรมวันนี้', '12', Icons.bolt_outlined),
        ],
      UserRole.superAdmin => [
          ('บัญชีในระบบ', '${_platformUsers.length}', Icons.people_outline),
          ('บทบาทที่กำหนด', '7', Icons.admin_panel_settings_outlined),
          ('รายการตรวจสอบ', '12', Icons.receipt_long_outlined),
        ],
      _ => <(String, String, IconData)>[],
    };
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth < 540 ? 1 : 3;
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: columns == 1 ? 4.1 : 1.4,
        children: [
          for (final item in values)
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.gray200)),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    CircleAvatar(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: .09),
                        child: Icon(item.$3, color: AppColors.primary)),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          Text(item.$2,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          Text(item.$1,
                              style: const TextStyle(color: AppColors.gray600)),
                        ])),
                  ])),
            )
        ],
      );
    });
  }

  Widget _content(_RoleSpec spec) => switch (widget.role) {
        UserRole.corporateAdmin => _corporateAdminContent(),
        UserRole.corporateManager => _corporateManagerContent(),
        UserRole.employer => _employerContent(),
        UserRole.admin => _adminContent(),
        UserRole.superAdmin => _superAdminContent(),
        _ => const SizedBox.shrink(),
      };

  Widget _corporateAdminContent() =>
      _panel('ภาพรวมองค์กร', 'ติดตามทีมและพัฒนาแผนเรียนให้ตรงกับเป้าหมาย', [
        if (_selectedTab == 0)
          ..._members.map((r) => _recordTile(r, Icons.person_outline,
              onTap: () => _toggle(r, 'เปลี่ยนสถานะสมาชิกแล้ว'))),
        if (_selectedTab == 1)
          ..._paths.map((r) => _recordTile(r, Icons.route_outlined,
              onTap: () => _toggle(r, 'อัปเดตสถานะแผนแล้ว'))),
        if (_selectedTab == 2)
          _recordTile(
              _Record('อัตราการเรียนจบ', 'สมาชิกเรียนจบอย่างน้อยหนึ่งคอร์ส',
                  '68%', true),
              Icons.analytics_outlined),
      ]);

  Widget _corporateManagerContent() =>
      _panel('ทีมของฉัน', 'ภาพความคืบหน้ารายบุคคลในทีม', [
        ..._members.map((r) => _recordTile(r, Icons.person_outline,
            trailing: TextButton.icon(
              onPressed: () => _toggle(r, 'อัปเดตความคืบหน้าทีมแล้ว'),
              icon: Icon(r.enabled
                  ? Icons.check_circle_outline
                  : Icons.play_circle_outline),
              label: Text(r.enabled ? 'กำลังเรียน' : 'มอบหมายคอร์ส'),
            ))),
        if (_selectedTab == 1)
          ..._paths.map((r) => _recordTile(r, Icons.menu_book_outlined)),
        if (_selectedTab == 2)
          _recordTile(
              _Record(
                  'ความคืบหน้าเฉลี่ย', 'เป้าหมายไตรมาสนี้ 80%', '72%', true),
              Icons.analytics_outlined),
      ]);

  Widget _employerContent() => _panel(
          _selectedTab == 0 ? 'ตำแหน่งงาน' : 'ผู้สมัคร',
          'จัดการการสรรหาและอัปเดตขั้นตอนผู้สมัคร', [
        if (_selectedTab == 0)
          ..._jobs.map((r) => _recordTile(r, Icons.work_outline,
              trailing: Switch(
                  value: r.enabled,
                  onChanged: (_) => _toggle(
                      r, r.enabled ? 'ปิดรับสมัครแล้ว' : 'เปิดรับสมัครแล้ว')))),
        if (_selectedTab == 1)
          ..._candidates
              .map((r) => _recordTile(r, Icons.account_circle_outlined,
                  trailing: PopupMenuButton<String>(
                      onSelected: (v) => setState(() => r.status = v),
                      itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'คัดกรองแล้ว',
                                child: Text('คัดกรองแล้ว')),
                            PopupMenuItem(
                                value: 'สัมภาษณ์', child: Text('นัดสัมภาษณ์')),
                            PopupMenuItem(
                                value: 'เสนอจ้าง', child: Text('เสนอจ้าง')),
                          ],
                      child: Chip(label: Text(r.status))))),
        if (_selectedTab == 2)
          _recordTile(
              _Record('ค้นหาผู้สมัคร', 'พบโปรไฟล์ที่ตรงกับทักษะของตำแหน่ง',
                  '8 คน', true),
              Icons.person_search_outlined),
      ]);

  Widget _adminContent() => _panel(
          _selectedTab == 0 ? 'บัญชีผู้ใช้' : 'ตรวจสอบคอร์ส',
          'ตรวจสอบและจัดการคุณภาพแพลตฟอร์ม', [
        if (_selectedTab == 0)
          ..._platformUsers.map((r) => _recordTile(r, Icons.person_outline,
              trailing: r.status == 'รอตรวจสอบ'
                  ? Wrap(spacing: 4, children: [
                      IconButton(
                          tooltip: 'อนุมัติ',
                          onPressed: () => _resolve(r, true),
                          icon: const Icon(Icons.check_circle_outline,
                              color: AppColors.success)),
                      IconButton(
                          tooltip: 'ปฏิเสธ',
                          onPressed: () => _resolve(r, false),
                          icon: const Icon(Icons.cancel_outlined,
                              color: AppColors.danger))
                    ])
                  : Switch(
                      value: r.enabled,
                      onChanged: (_) => _toggle(r, 'อัปเดตสถานะบัญชีแล้ว')))),
        if (_selectedTab == 1)
          ..._courses.map((r) => _recordTile(r, Icons.menu_book_outlined,
              trailing: r.status == 'รอตรวจ'
                  ? Wrap(spacing: 4, children: [
                      IconButton(
                          tooltip: 'อนุมัติคอร์ส',
                          onPressed: () => _resolve(r, true),
                          icon: const Icon(Icons.check_circle_outline,
                              color: AppColors.success)),
                      IconButton(
                          tooltip: 'ส่งกลับแก้ไข',
                          onPressed: () => _resolve(r, false),
                          icon: const Icon(Icons.edit_outlined,
                              color: AppColors.warning))
                    ])
                  : Chip(label: Text(r.status)))),
        if (_selectedTab == 2)
          _recordTile(
              _Record('รายการชำระเงิน', 'ธุรกรรมสำเร็จวันนี้', '฿24,900', true),
              Icons.payments_outlined),
      ]);

  Widget _superAdminContent() => _panel(
        _selectedTab == 0 ? 'Role directory' : 'Audit log',
        _selectedTab == 0
            ? 'ตรวจสอบบทบาทที่ได้รับมอบหมาย การเปลี่ยนสิทธิ์จริงต้องทำผ่านระบบฝั่งเซิร์ฟเวอร์'
            : 'ประวัติตัวอย่างของการดำเนินการสำคัญในระบบ',
        _selectedTab == 0
            ? [
                _recordTile(
                    _Record('learner@demo.co', 'Student · สิทธิ์พื้นฐาน',
                        'ใช้งานอยู่', true),
                    Icons.school_outlined),
                _recordTile(
                    _Record('instructor@demo.co', 'Instructor · คอร์สของตนเอง',
                        'ใช้งานอยู่', true),
                    Icons.co_present_outlined),
                _recordTile(
                    _Record('admin@demo.co', 'Admin · ตรวจสอบคอร์ส',
                        'ใช้งานอยู่', true),
                    Icons.admin_panel_settings_outlined),
                _recordTile(
                    _Record('superadmin@demo.co', 'Super Admin · นโยบายระบบ',
                        'จำกัดสิทธิ์', true),
                    Icons.security_outlined),
              ]
            : [
                _recordTile(
                    _Record('Course approval', 'admin@demo.co · วันนี้ 10:42',
                        'อนุมัติแล้ว', true),
                    Icons.fact_check_outlined),
                _recordTile(
                    _Record('Role claim issued',
                        'superadmin@demo.co · วันนี้ 09:18', 'สำเร็จ', true),
                    Icons.verified_user_outlined),
                _recordTile(
                    _Record('Enrollment created', 'learner@demo.co · เมื่อวาน',
                        'สำเร็จ', true),
                    Icons.school_outlined),
              ],
      );

  Widget _panel(String title, String subtitle, List<Widget> children) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.gray200)),
        child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 19)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: AppColors.gray600)),
              const SizedBox(height: 12),
              if (children.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('ยังไม่มีรายการ'))),
              ...children,
            ])),
      );

  Widget _recordTile(_Record record, IconData icon,
          {Widget? trailing, VoidCallback? onTap}) =>
      Card(
        elevation: 0,
        color: AppColors.gray50,
        child: ListTile(
            leading: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(icon, color: AppColors.primary)),
            title: Text(record.title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${record.detail} · ${record.status}'),
            trailing: trailing,
            onTap: onTap),
      );

  Widget? _actionFor(_RoleSpec spec) {
    if (widget.role != UserRole.corporateAdmin &&
        widget.role != UserRole.employer) {
      return null;
    }
    return FloatingActionButton.extended(
        onPressed: () => _createRecord(widget.role == UserRole.employer),
        icon: const Icon(Icons.add),
        label: Text(widget.role == UserRole.employer
            ? 'เพิ่มตำแหน่ง'
            : (_selectedTab == 1 ? 'สร้างแผนเรียน' : 'เพิ่มสมาชิก')));
  }

  Future<void> _createRecord(bool employer) async {
    _titleController.clear();
    _detailController.clear();
    final creatingJob = employer;
    final creatingPath = !employer && _selectedTab == 1;
    final title = creatingJob
        ? 'สร้างตำแหน่งงาน'
        : creatingPath
            ? 'สร้างแผนการเรียน'
            : 'เพิ่มสมาชิกองค์กร';
    final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text(title),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: _titleController,
                    autofocus: true,
                    decoration: InputDecoration(
                        labelText: creatingJob
                            ? 'ชื่อตำแหน่ง'
                            : creatingPath
                                ? 'ชื่อแผน'
                                : 'ชื่อสมาชิก')),
                const SizedBox(height: 12),
                TextField(
                    controller: _detailController,
                    decoration: InputDecoration(
                        labelText: creatingJob
                            ? 'สถานที่ / รูปแบบงาน'
                            : creatingPath
                                ? 'รายละเอียดแผน'
                                : 'อีเมล')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('ยกเลิก')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('บันทึก'))
              ],
            ));
    if (result == true &&
        _titleController.text.trim().isNotEmpty &&
        _detailController.text.trim().isNotEmpty) {
      setState(() {
        if (creatingJob) {
          _jobs.insert(
              0,
              _Record(_titleController.text.trim(),
                  _detailController.text.trim(), 'เปิดรับสมัคร', true));
        } else if (creatingPath) {
          _paths.insert(
              0,
              _Record(_titleController.text.trim(),
                  _detailController.text.trim(), 'ฉบับร่าง', false));
        } else {
          _members.insert(
              0,
              _Record(_titleController.text.trim(),
                  _detailController.text.trim(), 'รอมอบหมาย', false));
        }
      });
      _toast('บันทึกรายการแล้ว');
    }
  }

  void _toggle(_Record r, String message) {
    setState(() => r.enabled = !r.enabled);
    _toast(message);
  }

  void _resolve(_Record r, bool approved) {
    setState(() => r.status = approved ? 'อนุมัติแล้ว' : 'ส่งกลับแก้ไข');
    _toast(approved ? 'อนุมัติรายการแล้ว' : 'อัปเดตสถานะรายการแล้ว');
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
}

class _Record {
  _Record(this.title, this.detail, this.status, this.enabled);
  final String title;
  final String detail;
  String status;
  bool enabled;
}

class _RoleSpec {
  const _RoleSpec(
      this.title, this.heading, this.description, this.roleLabel, this.tabs);
  final String title, heading, description, roleLabel;
  final List<String> tabs;
}

_RoleSpec? _spec(UserRole role) => switch (role) {
      UserRole.corporateAdmin => const _RoleSpec(
          'Corporate Admin Dashboard',
          'จัดการการเรียนรู้ทั้งองค์กร',
          'จัดทีม วางแผนทักษะ และติดตามผลการเรียนรู้ในพื้นที่เดียว',
          'Corporate Admin',
          ['สมาชิก', 'แผนการเรียน', 'รายงาน']),
      UserRole.corporateManager => const _RoleSpec(
          'Corporate Manager Dashboard',
          'พัฒนาทีมด้วยการเรียนรู้',
          'ติดตามความคืบหน้าและมอบหมายการเรียนให้ทีม',
          'Corporate Manager',
          ['ทีมของฉัน', 'แผนการเรียน', 'ความคืบหน้า']),
      UserRole.employer => const _RoleSpec(
          'Employer Dashboard',
          'สรรหาคนที่ใช่ให้ทีม',
          'จัดการประกาศงานและติดตามผู้สมัครในทุกขั้นตอน',
          'Employer',
          ['ตำแหน่งงาน', 'ผู้สมัคร', 'ค้นหาคน']),
      UserRole.admin => const _RoleSpec(
          'Administration Dashboard',
          'ดูแลคุณภาพแพลตฟอร์ม',
          'จัดการบัญชี ตรวจสอบคอร์ส และติดตามกิจกรรมระบบ',
          'Administration',
          ['บัญชีผู้ใช้', 'ตรวจสอบคอร์ส', 'ธุรกรรม']),
      UserRole.superAdmin => const _RoleSpec(
          'Super Admin Dashboard',
          'กำกับนโยบายและสิทธิ์ระบบ',
          'ตรวจสอบบทบาทและ audit trail ด้วยสิทธิ์ระดับสูงแบบจำกัด',
          'Super Admin',
          ['Role directory', 'Audit logs']),
      _ => null,
    };

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.spec, required this.count});
  final _RoleSpec spec;
  final int count;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF2649D8), Color(0xFF5478FF)]),
            borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(spec.heading,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(spec.description,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 15)),
              ])),
          const SizedBox(width: 16),
          if (MediaQuery.sizeOf(context).width > 550)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Text('$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
                const Text('รายการหลัก',
                    style: TextStyle(color: Colors.white70))
              ]),
            ),
        ]),
      );
}
