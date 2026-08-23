import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/strings.dart';
import '../../state/app_state.dart';
import 'base_dialog.dart';

class WifiDialog extends StatefulWidget {
  const WifiDialog({super.key});
  @override
  State<WifiDialog> createState() => _WifiDialogState();
}

class _WifiDialogState extends State<WifiDialog> {
  final _passCtrl = TextEditingController();
  String? _selected;
  bool _scanning = false;
  bool _connecting = false;
  bool _obscure = true;

  final List<Map<String, dynamic>> _networks = [
    {'ssid': 'Hospital-WiFi-Internal', 'strength': 4, 'secure': true},
    {'ssid': 'HIS-Network-5G', 'strength': 3, 'secure': true},
    {'ssid': 'Ward-AP-2.4G', 'strength': 3, 'secure': true},
    {'ssid': 'Medical-Staff', 'strength': 2, 'secure': true},
    {'ssid': 'Guest-WiFi', 'strength': 2, 'secure': false},
  ];

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _connect() async {
    if (_selected == null) return;
    setState(() => _connecting = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    await context.read<AppState>().connectWifi(_selected!, _passCtrl.text);
    setState(() => _connecting = false);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${S.connected}: $_selected'),
        backgroundColor: AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseDialog(
      title: S.wifiConfig,
      icon: Icons.wifi_rounded,
      width: 420,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(S.availableNetworks, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const Spacer(),
              TextButton.icon(
                onPressed: _scanning ? null : _scan,
                icon: _scanning
                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.refresh_rounded, size: 14),
                label: Text(_scanning ? S.scanning : 'Scan', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(border: Border.all(color: AppColors.borderColor), borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: _networks.asMap().entries.map((e) {
                final i = e.key;
                final n = e.value;
                final isSelected = _selected == n['ssid'];
                return InkWell(
                  onTap: () => setState(() => _selected = n['ssid']),
                  borderRadius: i == 0
                      ? const BorderRadius.vertical(top: Radius.circular(7))
                      : i == _networks.length - 1
                          ? const BorderRadius.vertical(bottom: Radius.circular(7))
                          : BorderRadius.zero,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.lightBlue : Colors.transparent,
                      borderRadius: i == 0
                          ? const BorderRadius.vertical(top: Radius.circular(7))
                          : i == _networks.length - 1
                              ? const BorderRadius.vertical(bottom: Radius.circular(7))
                              : BorderRadius.zero,
                      border: i < _networks.length - 1 ? Border(bottom: BorderSide(color: AppColors.borderColor)) : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _wifiIcon(n['strength']),
                          size: 18,
                          color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(n['ssid'], style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary)),
                        ),
                        if (n['secure']) Icon(Icons.lock_rounded, size: 14, color: AppColors.textMuted),
                        if (isSelected) const SizedBox(width: 4),
                        if (isSelected) Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primaryBlue),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text(S.wifiPassword, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              hintText: S.enterWifiPassword,
              prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(S.cancel)),
        ElevatedButton.icon(
          onPressed: _selected == null || _connecting ? null : _connect,
          icon: _connecting
              ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(Icons.wifi_rounded, size: 16),
          label: Text(S.connect),
        ),
      ],
    );
  }

  IconData _wifiIcon(int strength) => strength >= 4
      ? Icons.signal_wifi_4_bar_rounded
      : strength == 3
          ? Icons.network_wifi_3_bar_rounded
          : Icons.network_wifi_2_bar_rounded;
}
