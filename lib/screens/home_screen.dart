import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/strings.dart';
import '../services/settings_service.dart';
import '../services/firebase_service.dart';
import '../state/app_state.dart';
import '../widgets/glass_container.dart';
import '../widgets/dialogs/wifi_dialog.dart';
import '../widgets/dialogs/password_dialog.dart';
import '../widgets/dialogs/firmware_dialog.dart';
import '../widgets/dialogs/speed_dialog.dart';
import '../widgets/dialogs/paper_dialog.dart';
import '../widgets/dialogs/base_dialog.dart';
import '../widgets/dialogs/his_dialog.dart';
import '../widgets/dialogs/firebase_login_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  bool _hasPassword() => SettingsService.instance.hasPassword;

  /// SRS §6.2 — verify admin password before opening a protected dialog.
  /// If no password is set, opens [dialog] directly.
  Future<void> _gated(BuildContext context, Widget dialog) async {
    if (!_hasPassword()) {
      if (context.mounted) {
        showDialog(context: context, builder: (_) => dialog);
      }
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _PasswordVerifyDialog(),
    );
    if (ok == true && context.mounted) {
      showDialog(context: context, builder: (_) => dialog);
    }
  }

  /// Same admin-password gate as [_gated], but for actions rather than dialogs
  /// (e.g. "Clear Local Data", which needs to run a confirm-then-delete flow).
  Future<void> _gatedAction(BuildContext context, Future<void> Function() action) async {
    if (!_hasPassword()) {
      await action();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _PasswordVerifyDialog(),
    );
    if (ok == true) await action();
  }

  /// Resets the LOCAL cache only. Once Firebase is signed in, this stops
  /// meaning "erase data" — the next sync just repopulates it from the
  /// cloud — so the copy/label makes that explicit rather than implying
  /// destruction of data that still exists remotely.
  Future<void> _confirmClearData(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => BaseDialog(
        title: S.resetLocalCache,
        icon: Icons.delete_sweep_rounded,
        width: 420,
        content: Text(S.resetLocalCacheWarning, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(S.clearDataConfirmBtn),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await state.clearAllData();
      if (context.mounted) showSuccess(context, S.clearDataSuccess);
    }
  }

  /// Deletes every patient/print record in the CLOUD for this hospital —
  /// affects every station syncing with it, unlike the local-only reset
  /// above. More heavily gated: requires typing a confirmation phrase in
  /// addition to the admin PIN, since this is a new, irreversible,
  /// shared-data-destroying capability that didn't exist before Firebase
  /// sync.
  Future<void> _confirmDeleteCloudData(BuildContext context, AppState state) async {
    final confirmCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final canProceed = confirmCtrl.text.trim() == 'CONFIRM';
          return BaseDialog(
            title: S.deleteCloudData,
            icon: Icons.delete_forever_rounded,
            width: 460,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.deleteCloudDataWarning, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 14),
                Text(S.typeConfirmToProceed, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                const SizedBox(height: 6),
                TextField(
                  controller: confirmCtrl,
                  autofocus: true,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'CONFIRM'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.cancel)),
              ElevatedButton(
                onPressed: canProceed ? () => Navigator.pop(ctx, true) : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: Text(S.deleteCloudData),
              ),
            ],
          );
        },
      ),
    );
    confirmCtrl.dispose();
    if (ok != true || !context.mounted) return;

    final result = await FirebaseService.instance.deleteAllHospitalData();
    if (!context.mounted) return;
    if (result.error != null) {
      showError(context, result.error!);
    } else {
      showSuccess(context, S.clearDataSuccess);
      await state.syncWithFirebase(); // refreshes the now-empty Patient List
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Stats row ─────────────────────────────────────────────────
              Row(children: [
                _StatCard(
                  label: S.totalPatients,
                  value: '${state.recentPatients.length}+',
                  icon: Icons.people_alt_rounded, color: AppColors.primaryBlue,
                  onTap: () => state.navigate(AppPage.patientList),
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: S.totalPrints,
                  value: '${state.pendingPrintCount}',
                  icon: Icons.print_rounded, color: AppColors.successGreen,
                  onTap: () => state.navigate(AppPage.printQueue),
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: S.readyToPrint,
                  value: state.readyToPrint ? 'Ready' : 'Offline',
                  icon: state.readyToPrint ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: state.readyToPrint ? AppColors.successGreen : AppColors.warningOrange,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'WiFi',
                  value: state.wifiSSID.isEmpty ? 'Not set' : state.wifiSSID,
                  icon: Icons.wifi_rounded, color: AppColors.accentBlue,
                  onTap: () => _gated(context, const WifiDialog()),
                ),
              ]),
              const SizedBox(height: 18),
              // ── Settings cards ─────────────────────────────────────────────
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: _GlassCard(
                    title: S.systemSettings,
                    icon: Icons.settings_rounded,
                    iconColor: AppColors.primaryBlue,
                    children: [
                      // WiFi — password gated (SRS §6.2)
                      _SettingRow(
                        icon: Icons.wifi_rounded, label: S.setWifi,
                        sub: state.wifiStatus.isEmpty ? 'Not configured' : state.wifiStatus,
                        color: AppColors.successGreen,
                        badge: _hasPassword() ? Icons.shield_rounded : null,
                        onTap: () => _gated(context, const WifiDialog()),
                      ),
                      // Password — always accessible (it IS the gate)
                      _SettingRow(
                        icon: Icons.lock_rounded, label: S.setPassword,
                        sub: _hasPassword() ? '••••••' : 'Not set',
                        color: AppColors.warningOrange,
                        onTap: () => showDialog(context: context, builder: (_) => const PasswordDialog()),
                      ),
                      // Firmware — password gated (SRS §6.2)
                      _SettingRow(
                        icon: Icons.memory_rounded, label: S.firmwareVersion,
                        sub: state.firmwareVersion, color: AppColors.accentBlue,
                        badge: _hasPassword() ? Icons.shield_rounded : null,
                        onTap: () => _gated(context, const FirmwareDialog()),
                      ),
                      // HIS Connection
                      _SettingRow(
                        icon: Icons.hub_rounded,
                        label: S.hisConnection,
                        sub: SettingsService.instance.hisConfig.isConfigured
                            ? '${S.hisConnected}: ${SettingsService.instance.hisConfig.baseUrl}'
                            : S.hisNotConnected,
                        color: SettingsService.instance.hisConfig.isConfigured
                            ? AppColors.successGreen
                            : AppColors.textMuted,
                        onTap: () async {
                          await showHisDialog(context);
                          if (context.mounted) state.refresh();
                        },
                      ),
                      // Cloud Sync (Firebase) — PIN gated: unlike HIS config,
                      // this credential has live read/write access to the
                      // hospital's entire cloud dataset, not just a pointer
                      // to a hospital-internal server.
                      _SettingRow(
                        icon: Icons.cloud_rounded,
                        label: S.cloudSync,
                        sub: state.isCloudSignedIn
                            ? '${S.cloudSignedIn}: ${state.cloudEmail}'
                            : S.cloudNotSignedIn,
                        color: state.isCloudSignedIn ? AppColors.successGreen : AppColors.textMuted,
                        badge: _hasPassword() ? Icons.shield_rounded : null,
                        onTap: () => _gatedAction(context, () async {
                          await showFirebaseLoginDialog(context);
                          if (context.mounted) state.refresh();
                        }),
                      ),
                      // Clear Local Data — resets the local cache only
                      _SettingRow(
                        icon: Icons.delete_sweep_rounded,
                        label: S.resetLocalCache,
                        sub: '${state.totalPatientCount} patients · ${state.totalPrintCount} prints',
                        color: AppColors.errorRed,
                        badge: _hasPassword() ? Icons.shield_rounded : null,
                        onTap: () => _gatedAction(context, () => _confirmClearData(context, state)),
                      ),
                      // Delete All Cloud Data — only shown once signed in;
                      // affects every station sharing this hospital account.
                      if (state.isCloudSignedIn)
                        _SettingRow(
                          icon: Icons.delete_forever_rounded,
                          label: S.deleteCloudData,
                          sub: '${S.cloudSignedInAs}: ${state.cloudEmail}',
                          color: AppColors.errorRed,
                          badge: _hasPassword() ? Icons.shield_rounded : null,
                          onTap: () => _gatedAction(context, () => _confirmDeleteCloudData(context, state)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _GlassCard(
                    title: S.printSettings,
                    icon: Icons.print_rounded,
                    iconColor: AppColors.accentBlue,
                    children: [
                      _SettingRow(
                        icon: Icons.speed_rounded, label: S.printSpeed,
                        sub: '${S.gear} ${state.printSpeed}', color: AppColors.primaryBlue,
                        onTap: () => showDialog(context: context, builder: (_) => SpeedDialog(current: state.printSpeed)),
                      ),
                      _SettingRow(
                        icon: Icons.contrast_rounded, label: S.printDensity,
                        sub: '${S.gear} ${state.printDensity}', color: AppColors.primaryBlue,
                        onTap: () => showDialog(context: context, builder: (_) => DensityDialog(current: state.printDensity)),
                      ),
                      // Paper size — all 35 BB720A configs (SRS §4 / Printer Config PDF)
                      _SettingRow(
                        icon: Icons.straighten_rounded, label: S.paperSize,
                        sub: state.paperConfig.shortLabel, color: AppColors.accentBlue,
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => PaperDialog(
                            currentItemNo:    state.selectedPaperItemNo,
                            currentPrinterName: state.printerName,
                            currentChannel:   state.printChannel,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              // ── Dual data preview lists (SRS §3.1.1) ─────────────────────
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: _PreviewList(
                    title: S.recentPatients,
                    icon: Icons.people_rounded,
                    color: AppColors.primaryBlue,
                    onViewAll: () => state.navigate(AppPage.patientList),
                    isEmpty: state.recentPatients.isEmpty,
                    emptyMsg: S.noPatients,
                    rows: state.recentPatients.map((p) => _PreviewRow(
                      name: p.name, id: p.patientId, right: p.admissionTime,
                    )).toList(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _PreviewList(
                    title: S.recentPrints,
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.successGreen,
                    onViewAll: () => state.navigate(AppPage.printQueue),
                    isEmpty: state.recentPrintRecords.isEmpty,
                    emptyMsg: S.noPrintRecords,
                    rows: state.recentPrintRecords.map((r) => _PreviewRow(
                      name: r.name, id: r.patientId,
                      right: '${r.printTime.year}.${r.printTime.month.toString().padLeft(2,'0')}.${r.printTime.day.toString().padLeft(2,'0')}',
                    )).toList(),
                  ),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }
}

// ─── Password verify gate dialog (SRS §6.2) ──────────────────────────────────

class _PasswordVerifyDialog extends StatefulWidget {
  @override
  State<_PasswordVerifyDialog> createState() => _PasswordVerifyDialogState();
}

class _PasswordVerifyDialogState extends State<_PasswordVerifyDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _verify() {
    if (SettingsService.instance.verifyPassword(_ctrl.text)) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = S.wrongPassword);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseDialog(
      title: S.confirm,
      icon: Icons.shield_rounded,
      width: 360,
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(S.enterAdminPassword, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          obscureText: _obscure,
          autofocus: true,
          onSubmitted: (_) => _verify(),
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.lock_outline_rounded, size: 16),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 16),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            errorText: _error,
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(S.cancel)),
        ElevatedButton(
          onPressed: _verify,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: Text(S.confirm),
        ),
      ],
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassBox(
        blur: 25,
        opacity: 0.08,
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color), overflow: TextOverflow.ellipsis),
                Text(label, style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
              ],
            )),
            if (onTap != null) Icon(Icons.arrow_forward_ios_rounded, size: 12, color: color.withValues(alpha: 0.5)),
          ]),
        ),
      ),
    );
  }
}

// ─── Settings glass card ──────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _GlassCard({required this.title, required this.icon, required this.iconColor, required this.children});

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      blur: 25,
      opacity: 0.07,
      borderRadius: BorderRadius.circular(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ]),
        ),
        Divider(color: AppColors.glassBorder, height: 1),
        ...children,
        const SizedBox(height: 4),
      ]),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback onTap;
  final IconData? badge;

  const _SettingRow({
    required this.icon, required this.label, required this.sub,
    required this.color, required this.onTap, this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: Colors.white.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                if (badge != null) ...[
                  const SizedBox(width: 4),
                  Icon(badge, size: 11, color: AppColors.warningOrange.withValues(alpha: 0.7)),
                ],
              ]),
              Text(sub, style: TextStyle(fontSize: 11, color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
            ])),
            Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
          ]),
        ),
      ),
    );
  }
}

// ─── Preview list with right-arrow pagination (SRS §3.1.1) ───────────────────

class _PreviewList extends StatelessWidget {
  final String title, emptyMsg;
  final IconData icon;
  final Color color;
  final VoidCallback onViewAll;
  final bool isEmpty;
  final List<Widget> rows;

  const _PreviewList({
    required this.title, required this.icon, required this.color,
    required this.onViewAll, required this.isEmpty, required this.emptyMsg, required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      blur: 25,
      opacity: 0.07,
      borderRadius: BorderRadius.circular(16),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            GestureDetector(
              onTap: onViewAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(S.viewAll, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 3),
                  Icon(Icons.arrow_forward_ios_rounded, size: 10, color: color),
                ]),
              ),
            ),
          ]),
        ),
        Divider(color: AppColors.glassBorder, height: 1),
        if (isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(emptyMsg, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          )
        else
          ...rows,
        const SizedBox(height: 4),
      ]),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String name, id, right;
  const _PreviewRow({required this.name, required this.id, required this.right});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25)),
          ),
          child: Center(child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(color: AppColors.accentBlue, fontSize: 12, fontWeight: FontWeight.w700),
          )),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
          Text('$id  •  $right', style: TextStyle(fontSize: 10, color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}
