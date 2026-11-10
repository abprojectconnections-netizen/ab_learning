import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/role_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../workspace/domain/workspace_models.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';

/// Role workspaces backed by live Firestore data (see workspace_providers).
/// Every mutation goes through the repositories, which enforce the same
/// permissions as firestore.rules / Cloud Functions.
class RoleDashboardScreen extends ConsumerStatefulWidget {
  const RoleDashboardScreen({super.key, required this.role});
  final UserRole role;

  @override
  ConsumerState<RoleDashboardScreen> createState() => _RoleDashboardScreenState();
}

class _RoleDashboardScreenState extends ConsumerState<RoleDashboardScreen> {
  final _titleController = TextEditingController();
  final _detailController = TextEditingController();
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
      return const Scaffold(body: Center(child: Text('ไม่พบหน้าสำหรับสิทธิ์นี้')));
    }
    final tabs = spec.tabs;
    _selectedTab = _selectedTab.clamp(0, tabs.length - 1);
    final width = MediaQuery.sizeOf(context).width;
    final metrics = _metricValues();
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
              _HeroPanel(spec: spec, count: metrics.primary),
              const SizedBox(height: 20),
              _metricsGrid(metrics.items),
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
              _content(),
            ],
          ),
        ),
      ),
      floatingActionButton: _actionFor(),
    );
  }

  // ---- metrics (derived from live providers) ------------------------------

  ({int primary, List<(String, String, IconData)> items}) _metricValues() {
    String n(AsyncValue<List<Object?>> a) => a.hasValue ? '${a.value!.length}' : '…';
    int c(AsyncValue<List<Object?>> a) => a.valueOrNull?.length ?? 0;
    switch (widget.role) {
      case UserRole.corporateAdmin:
      case UserRole.corporateManager:
        final members = ref.watch(orgMembersProvider);
        final paths = ref.watch(learningPathsProvider);
        final active = members.valueOrNull?.where((m) => m.isActive).length;
        return (primary: c(members), items: [
          ('สมาชิกทั้งหมด', n(members), Icons.groups_outlined),
          ('แผนการเรียน', n(paths), Icons.route_outlined),
          ('สมาชิกที่ใช้งานอยู่', active == null ? '…' : '$active', Icons.trending_up),
        ]);
      case UserRole.employer:
        final jobs = ref.watch(myJobsProvider);
        final apps = ref.watch(jobApplicationsProvider);
        final open = jobs.valueOrNull?.where((j) => j.isOpen).length;
        final fresh = apps.valueOrNull?.where((a) => a.status == 'new').length;
        return (primary: open ?? 0, items: [
          ('ตำแหน่งที่เปิด', open == null ? '…' : '$open', Icons.work_outline),
          ('ผู้สมัคร', n(apps), Icons.person_search_outlined),
          ('รอตรวจ', fresh == null ? '…' : '$fresh', Icons.inbox_outlined),
        ]);
      case UserRole.admin:
        final users = ref.watch(adminUsersProvider);
        final courses = ref.watch(pendingCoursesProvider);
        final sales = ref.watch(salesTodayProvider);
        return (primary: c(courses), items: [
          ('ผู้ใช้', n(users), Icons.people_outline),
          ('คอร์สรอตรวจ', n(courses), Icons.fact_check_outlined),
          ('ธุรกรรมวันนี้', sales.hasValue ? '${sales.value!.count}' : '…', Icons.bolt_outlined),
        ]);
      case UserRole.superAdmin:
        final users = ref.watch(adminUsersProvider);
        final audit = ref.watch(auditLogProvider);
        final roles = users.valueOrNull?.map((u) => u.role).toSet().length;
        return (primary: c(users), items: [
          ('บัญชีในระบบ', n(users), Icons.people_outline),
          ('บทบาทที่ใช้งาน', roles == null ? '…' : '$roles', Icons.admin_panel_settings_outlined),
          ('รายการตรวจสอบล่าสุด', n(audit), Icons.receipt_long_outlined),
        ]);
      default:
        return (primary: 0, items: const <(String, String, IconData)>[]);
    }
  }

  Widget _metricsGrid(List<(String, String, IconData)> values) {
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
                        backgroundColor: AppColors.primary.withValues(alpha: .09),
                        child: Icon(item.$3, color: AppColors.primary)),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          Text(item.$2,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          Text(item.$1, style: const TextStyle(color: AppColors.gray600)),
                        ])),
                  ])),
            )
        ],
      );
    });
  }

  // ---- content -------------------------------------------------------------

  Widget _content() => switch (widget.role) {
        UserRole.corporateAdmin => _corporateContent(canManage: true),
        UserRole.corporateManager => _corporateContent(canManage: false),
        UserRole.employer => _employerContent(),
        UserRole.admin => _adminContent(),
        UserRole.superAdmin => _superAdminContent(),
        _ => const SizedBox.shrink(),
      };

  Widget _corporateContent({required bool canManage}) {
    final staff = ref.watch(staffMembershipProvider);
    if (staff.hasValue && staff.value == null) {
      return _panel('ยังไม่มีองค์กร', 'บัญชีนี้ยังไม่ได้ถูกเชื่อมกับองค์กร กรุณาติดต่อผู้ดูแลระบบ', const SizedBox.shrink());
    }
    switch (_selectedTab) {
      case 0:
        if (canManage) {
          return _panel('สมาชิกองค์กร', 'จัดการสมาชิกและสถานะการใช้งาน',
              _asyncList<OrgMember>(ref.watch(orgMembersProvider), (m) {
            return _tile(m.displayName, '${m.email} · ${_roleLabel(m.role)}', m.isActive ? 'ใช้งานอยู่' : 'ระงับ', Icons.person_outline,
                trailing: m.role == 'admin'
                    ? null
                    : Switch(
                        value: m.isActive,
                        onChanged: (v) => _run(
                            () => ref.read(orgRepositoryProvider).setMemberStatus(m.orgId, m.uid, v ? 'active' : 'suspended'),
                            refresh: [orgMembersProvider, teamProgressProvider],
                            success: 'อัปเดตสถานะสมาชิกแล้ว')));
          }));
        }
        return _panel('ทีมของฉัน', 'ความคืบหน้ารายบุคคลในองค์กร',
            _asyncList<TeamMemberProgress>(ref.watch(teamProgressProvider), (t) {
          return _tile(t.displayName, '${t.email} · กำลังเรียน ${t.enrolledCourses} คอร์ส', 'เรียนจบ ${t.completedCourses}', Icons.person_outline);
        }));
      case 1:
        return _panel('แผนการเรียน', 'ชุดคอร์สที่องค์กรกำหนดให้ทีม',
            _asyncList<LearningPath>(ref.watch(learningPathsProvider), (p) {
          return _tile(p.title, p.description, _pathLabel(p.status), Icons.route_outlined,
              trailing: canManage
                  ? Switch(
                      value: p.status == 'active',
                      onChanged: (v) => _run(
                          () => ref.read(orgRepositoryProvider).setPathStatus(p.id, v ? 'active' : 'draft'),
                          refresh: [learningPathsProvider],
                          success: 'อัปเดตสถานะแผนแล้ว'))
                  : null);
        }));
      default:
        final team = ref.watch(teamProgressProvider);
        return _panel('รายงาน', 'สรุปการเรียนรู้ทั้งองค์กร', team.when(
          loading: _loading,
          error: (e, _) => _error(() => ref.invalidate(teamProgressProvider)),
          data: (rows) {
            final enrolled = rows.fold<int>(0, (a, r) => a + r.enrolledCourses);
            final completed = rows.fold<int>(0, (a, r) => a + r.completedCourses);
            final learners = rows.where((r) => r.completedCourses > 0).length;
            final rate = rows.isEmpty ? 0 : (learners * 100 / rows.length).round();
            return Column(children: [
              _tile('อัตราผู้เรียนจบอย่างน้อยหนึ่งคอร์ส', '$learners จาก ${rows.length} คน', '$rate%', Icons.analytics_outlined),
              _tile('คอร์สที่กำลังเรียน', 'รวมทุกคนในองค์กร', '$enrolled', Icons.menu_book_outlined),
              _tile('ใบประกาศนียบัตรที่ได้รับ', 'รวมทุกคนในองค์กร', '$completed', Icons.workspace_premium_outlined),
            ]);
          },
        ));
    }
  }

  Widget _employerContent() {
    if (_selectedTab == 0) {
      return _panel('ตำแหน่งงาน', 'จัดการประกาศงานของคุณ',
          _asyncList<JobPosting>(ref.watch(myJobsProvider), (j) {
        return _tile(j.title, j.location, j.isOpen ? 'เปิดรับสมัคร' : 'ปิดรับสมัคร', Icons.work_outline,
            trailing: Switch(
                value: j.isOpen,
                onChanged: (v) => _run(() => ref.read(recruitmentRepositoryProvider).setJobStatus(j.id, v ? 'open' : 'closed'),
                    refresh: [myJobsProvider], success: v ? 'เปิดรับสมัครแล้ว' : 'ปิดรับสมัครแล้ว')));
      }));
    }
    final jobs = {for (final j in ref.watch(myJobsProvider).valueOrNull ?? const <JobPosting>[]) j.id: j.title};
    return _panel('ผู้สมัคร', 'อัปเดตขั้นตอนผู้สมัครในแต่ละตำแหน่ง',
        _asyncList<JobApplication>(ref.watch(jobApplicationsProvider), (a) {
      return _tile(a.candidateName, jobs[a.jobId] ?? a.jobId, _appLabel(a.status), Icons.account_circle_outlined,
          trailing: PopupMenuButton<String>(
              onSelected: (v) => _run(() => ref.read(recruitmentRepositoryProvider).setApplicationStatus(a.id, v),
                  refresh: [jobApplicationsProvider], success: 'อัปเดตสถานะผู้สมัครแล้ว'),
              itemBuilder: (_) => const [
                    PopupMenuItem(value: 'screened', child: Text('คัดกรองแล้ว')),
                    PopupMenuItem(value: 'interview', child: Text('นัดสัมภาษณ์')),
                    PopupMenuItem(value: 'offer', child: Text('เสนอจ้าง')),
                    PopupMenuItem(value: 'rejected', child: Text('ไม่ผ่าน')),
                  ],
              child: Chip(label: Text(_appLabel(a.status)))));
    }));
  }

  Widget _adminContent() {
    switch (_selectedTab) {
      case 0:
        final apps = ref.watch(pendingInstructorApplicationsProvider);
        return _panel('บัญชีผู้ใช้', 'อนุมัติผู้สอนและจัดการสถานะบัญชี', Column(children: [
          _asyncList<InstructorApplication>(apps, (a) {
            return _tile(a.displayName, 'สมัครเป็นผู้สอน · ${a.experience}', 'รอตรวจสอบ', Icons.co_present_outlined,
                trailing: IconButton(
                    tooltip: 'อนุมัติ',
                    onPressed: () => _run(() => ref.read(adminRepositoryProvider).approveInstructorApplication(a.id),
                        refresh: [pendingInstructorApplicationsProvider, adminUsersProvider], success: 'อนุมัติผู้สอนแล้ว'),
                    icon: const Icon(Icons.check_circle_outline, color: AppColors.success)));
          }, empty: ''),
          _asyncList<AdminUser>(ref.watch(adminUsersProvider), (u) {
            return _tile(u.displayName.isEmpty ? u.email : u.displayName, '${u.email} · ${_roleLabel(u.role)}', u.isActive ? 'ใช้งานอยู่' : 'ระงับ', Icons.person_outline,
                trailing: Switch(
                    value: u.isActive,
                    onChanged: (v) => _run(() => ref.read(adminRepositoryProvider).setUserStatus(u.uid, v ? 'active' : 'suspended'),
                        refresh: [adminUsersProvider], success: 'อัปเดตสถานะบัญชีแล้ว')));
          }),
        ]));
      case 1:
        return _panel('ตรวจสอบคอร์ส', 'คอร์สที่ผู้สอนส่งขอเผยแพร่',
            _asyncList<PendingCourse>(ref.watch(pendingCoursesProvider), (c) {
          return _tile(c.title, c.instructorName, 'รอตรวจ', Icons.menu_book_outlined,
              trailing: Wrap(spacing: 4, children: [
                IconButton(
                    tooltip: 'อนุมัติคอร์ส',
                    onPressed: () => _run(() => ref.read(adminRepositoryProvider).reviewCourse(c.id, approve: true),
                        refresh: [pendingCoursesProvider], success: 'อนุมัติคอร์สแล้ว'),
                    icon: const Icon(Icons.check_circle_outline, color: AppColors.success)),
                IconButton(
                    tooltip: 'ส่งกลับแก้ไข',
                    onPressed: () => _run(() => ref.read(adminRepositoryProvider).reviewCourse(c.id, approve: false),
                        refresh: [pendingCoursesProvider], success: 'ส่งกลับแก้ไขแล้ว'),
                    icon: const Icon(Icons.edit_outlined, color: AppColors.warning)),
              ]));
        }));
      default:
        return _panel('ธุรกรรม', 'ยอดขายของวันนี้', ref.watch(salesTodayProvider).when(
              loading: _loading,
              error: (e, _) => _error(() => ref.invalidate(salesTodayProvider)),
              data: (s) => _tile('รายการชำระเงิน', '${s.count} ธุรกรรมวันนี้', '฿${s.total.toStringAsFixed(0)}', Icons.payments_outlined),
            ));
    }
  }

  Widget _superAdminContent() {
    if (_selectedTab == 0) {
      return _panel('Role directory', 'กำหนดบทบาทผ่าน Cloud Function พร้อมบันทึก audit',
          _asyncList<AdminUser>(ref.watch(adminUsersProvider), (u) {
        return _tile(u.displayName.isEmpty ? u.email : u.displayName, u.email, _roleLabel(u.role), Icons.admin_panel_settings_outlined,
            trailing: PopupMenuButton<String>(
                tooltip: 'เปลี่ยนบทบาท',
                onSelected: (role) => _run(() => ref.read(adminRepositoryProvider).setUserRole(u.uid, role),
                    refresh: [adminUsersProvider, auditLogProvider], success: 'เปลี่ยนบทบาทแล้ว (ผู้ใช้ต้องเข้าสู่ระบบใหม่)'),
                itemBuilder: (_) => [
                      for (final r in _allRoles) PopupMenuItem(value: r, child: Text(_roleLabel(r))),
                    ],
                child: const Icon(Icons.more_vert)));
      }));
    }
    return _panel('Audit log', 'ประวัติการดำเนินการสำคัญของระบบ',
        _asyncList<AuditEntry>(ref.watch(auditLogProvider), (e) {
      final t = e.createdAt;
      final when = t == null ? '' : ' · ${t.day}/${t.month} ${t.hour}:${t.minute.toString().padLeft(2, '0')}';
      return _tile(e.action, '${e.targetType} · ${e.actorUid}$when', 'บันทึกแล้ว', Icons.fact_check_outlined);
    }));
  }

  // ---- shared widgets & helpers -----------------------------------------------

  Widget _loading() => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));

  Widget _error(VoidCallback retry) => Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
          child: Column(children: [
        const Text('โหลดข้อมูลไม่สำเร็จ'),
        TextButton(onPressed: retry, child: const Text('ลองใหม่')),
      ])));

  Widget _asyncList<T>(AsyncValue<List<T>> async, Widget Function(T) item, {String empty = 'ยังไม่มีรายการ'}) {
    return async.when(
      loading: _loading,
      error: (e, _) => _error(() {}),
      data: (items) {
        if (items.isEmpty) {
          return empty.isEmpty
              ? const SizedBox.shrink()
              : Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(empty)));
        }
        return Column(children: [for (final i in items) item(i)]);
      },
    );
  }

  Widget _panel(String title, String subtitle, Widget child) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.gray200)),
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: AppColors.gray600)),
              const SizedBox(height: 12),
              child,
            ])),
      );

  Widget _tile(String title, String detail, String status, IconData icon, {Widget? trailing}) => Card(
        elevation: 0,
        color: AppColors.gray50,
        child: ListTile(
            leading: CircleAvatar(backgroundColor: Colors.white, child: Icon(icon, color: AppColors.primary)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('$detail · $status'),
            trailing: trailing),
      );

  /// Runs a repository action, refreshes the affected providers and reports
  /// the outcome. Permission failures from rules/functions surface as a toast.
  Future<void> _run(Future<void> Function() action,
      {required List<ProviderOrFamily> refresh, required String success}) async {
    try {
      await action();
      for (final p in refresh) {
        ref.invalidate(p);
      }
      _toast(success);
    } catch (_) {
      _toast('ดำเนินการไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  Widget? _actionFor() {
    final isEmployer = widget.role == UserRole.employer;
    final isCorpAdmin = widget.role == UserRole.corporateAdmin;
    if (!isEmployer && !isCorpAdmin) return null;
    if (isCorpAdmin && _selectedTab > 1) return null;
    if (isEmployer && _selectedTab != 0) return null;
    return FloatingActionButton.extended(
        onPressed: () => _create(isEmployer),
        icon: const Icon(Icons.add),
        label: Text(isEmployer ? 'เพิ่มตำแหน่ง' : (_selectedTab == 1 ? 'สร้างแผนเรียน' : 'เพิ่มสมาชิก')));
  }

  Future<void> _create(bool employer) async {
    _titleController.clear();
    _detailController.clear();
    final creatingPath = !employer && _selectedTab == 1;
    final dialogTitle = employer ? 'สร้างตำแหน่งงาน' : creatingPath ? 'สร้างแผนการเรียน' : 'เพิ่มสมาชิกองค์กร';
    final addingMember = !employer && !creatingPath;
    final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text(dialogTitle),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: _titleController,
                    autofocus: true,
                    keyboardType: addingMember ? TextInputType.emailAddress : TextInputType.text,
                    decoration: InputDecoration(labelText: employer ? 'ชื่อตำแหน่ง' : creatingPath ? 'ชื่อแผน' : 'อีเมลของสมาชิก')),
                if (!addingMember) ...[
                  const SizedBox(height: 12),
                  TextField(
                      controller: _detailController,
                      decoration: InputDecoration(labelText: employer ? 'สถานที่ / รูปแบบงาน' : 'รายละเอียดแผน')),
                ],
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('ยกเลิก')),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('บันทึก')),
              ],
            ));
    final first = _titleController.text.trim();
    final second = _detailController.text.trim();
    if (ok != true || first.isEmpty || (!addingMember && second.isEmpty)) return;
    if (employer) {
      await _run(() => ref.read(recruitmentRepositoryProvider).createJob(title: first, location: second),
          refresh: [myJobsProvider], success: 'เพิ่มตำแหน่งงานแล้ว');
    } else if (creatingPath) {
      final me = await ref.read(staffMembershipProvider.future);
      if (me == null) return _toast('ไม่พบองค์กรของคุณ');
      await _run(() => ref.read(orgRepositoryProvider).createPath(me.orgId, title: first, description: second),
          refresh: [learningPathsProvider], success: 'สร้างแผนการเรียนแล้ว');
    } else {
      await _run(() => ref.read(orgRepositoryProvider).addMember(first),
          refresh: [orgMembersProvider, teamProgressProvider], success: 'เพิ่มสมาชิกแล้ว');
    }
  }
}

const _allRoles = [
  'learner', 'instructor', 'corporate_admin', 'corporate_manager', 'employer', 'admin', 'super_admin',
];

String _roleLabel(String role) => switch (role) {
      'learner' => 'ผู้เรียน',
      'instructor' => 'ผู้สอน',
      'corporate_admin' => 'Corporate Admin',
      'corporate_manager' => 'Corporate Manager',
      'employer' => 'นายจ้าง',
      'admin' => 'ผู้ดูแลระบบ',
      'super_admin' => 'Super Admin',
      'manager' => 'ผู้จัดการทีม',
      'member' => 'สมาชิก',
      _ => role,
    };

String _pathLabel(String status) => switch (status) {
      'active' => 'กำลังใช้งาน',
      'archived' => 'เก็บถาวร',
      _ => 'ฉบับร่าง',
    };

String _appLabel(String status) => switch (status) {
      'screened' => 'คัดกรองแล้ว',
      'interview' => 'สัมภาษณ์',
      'offer' => 'เสนอจ้าง',
      'rejected' => 'ไม่ผ่าน',
      _ => 'ใหม่',
    };

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
          ['ตำแหน่งงาน', 'ผู้สมัคร']),
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
