import 'package:flutter/material.dart';
import '../core/core.dart';
import '../core/api_extension.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class ApiScreen extends StatefulWidget {
  const ApiScreen({super.key});

  @override
  State<ApiScreen> createState() => _ApiScreenState();
}

class _ApiScreenState extends State<ApiScreen> {
  final _portController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _portController.text = core.settings.current.apiPort.toString();
  }

  @override
  void dispose() {
    _portController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = core.settings.current;
    final styles = AppTheme.of(context);
    final colors = AppColorsExtension.of(context);
    final api = core.api;

    return Container(
      color: colors.background,
      child: Column(
        children: [
          _buildHeader(styles, colors),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  children: [
                    // Server section
                    _buildSection(
                      colors: colors,
                      title: 'Server',
                      icon: Icons.dns,
                      children: [
                        Row(
                          children: [
                            // Status indicator
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: api.isRunning ? AppColors.running : colors.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              api.isRunning
                                  ? 'Running on 127.0.0.1:${api.boundPort}'
                                  : 'Stopped',
                              style: TextStyle(
                                fontSize: 13,
                                color: api.isRunning ? colors.textPrimary : colors.textMuted,
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              value: api.isRunning,
                              activeColor: AppColors.accent,
                              onChanged: (enabled) async {
                                if (enabled) {
                                  await core.api.start();
                                  await core.settings.setApiEnabled(true);
                                } else {
                                  await core.api.stop();
                                  await core.settings.setApiEnabled(false);
                                }
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Configuration section
                    _buildSection(
                      colors: colors,
                      title: 'Configuration',
                      icon: Icons.tune,
                      children: [
                        // Port
                        Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text('Port', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                            ),
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _portController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'Consolas',
                                  color: colors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(color: colors.border),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () async {
                                final port = int.tryParse(_portController.text);
                                if (port == null) return;
                                await core.settings.setApiPort(port);
                                // Restart server if running
                                if (api.isRunning) {
                                  await core.api.stop();
                                  await core.api.start();
                                }
                                setState(() {});
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                              child: Text('Apply', style: TextStyle(fontSize: 12, color: AppColors.accent)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Timestamp tolerance
                        Row(
                          children: [
                            Text('Timestamp Tolerance', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.surfaceLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${settings.apiTimestampTolerance}s',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Consolas',
                                  fontWeight: FontWeight.bold,
                                  color: colors.textBright,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: AppColors.accent,
                            inactiveTrackColor: colors.surfaceLight,
                            thumbColor: AppColors.accent,
                            overlayColor: AppColors.accent.withAlpha(30),
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: settings.apiTimestampTolerance.toDouble(),
                            min: 30,
                            max: 3600,
                            divisions: 119,
                            onChanged: (v) async {
                              await core.settings.setApiTimestampTolerance(v.round());
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Allowed Addresses section
                    _buildSection(
                      colors: colors,
                      title: 'Allowed Addresses',
                      icon: Icons.verified_user,
                      children: [
                        if (settings.apiAllowedAddresses.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.warning.withAlpha(60)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'No addresses configured — auth is disabled',
                                    style: TextStyle(fontSize: 12, color: AppColors.warning),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ...settings.apiAllowedAddresses.map((addr) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      addr,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'Consolas',
                                        color: colors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close, size: 14, color: colors.textMuted),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                    onPressed: () async {
                                      await core.settings.removeApiAllowedAddress(addr);
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            )),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _addressController,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Consolas',
                                  color: colors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: '0x...',
                                  hintStyle: TextStyle(color: colors.textMuted, fontSize: 12),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(color: colors.border),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.add, size: 18, color: AppColors.accent),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () async {
                                final addr = _addressController.text.trim();
                                if (addr.isEmpty || !addr.startsWith('0x')) return;
                                await core.settings.addApiAllowedAddress(addr);
                                _addressController.clear();
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Endpoints section
                    _buildSection(
                      colors: colors,
                      title: 'Endpoints',
                      icon: Icons.route,
                      children: [
                        ...ApiExtension.endpoints.map((ep) {
                          final enabled = settings.apiEndpointToggles[ep.action] ?? true;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    ep.method,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'Consolas',
                                      fontWeight: FontWeight.bold,
                                      color: ep.method == 'GET'
                                          ? AppColors.info
                                          : AppColors.running,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    ep.path,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'Consolas',
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 28,
                                  child: Switch(
                                    value: enabled,
                                    activeColor: AppColors.accent,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    onChanged: (v) async {
                                      await core.settings.setApiEndpointEnabled(ep.action, v);
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Request Log section
                    _buildSection(
                      colors: colors,
                      title: 'Request Log',
                      icon: Icons.list_alt,
                      children: [
                        if (api.requestLog.isEmpty)
                          Text(
                            'No requests yet',
                            style: TextStyle(fontSize: 12, color: colors.textMuted),
                          )
                        else
                          ...api.requestLog.take(50).map((entry) {
                            final time =
                                '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
                                '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
                                '${entry.timestamp.second.toString().padLeft(2, '0')}';

                            final methodColor = entry.method == 'GET'
                                ? AppColors.info
                                : AppColors.running;

                            Color statusColor;
                            if (entry.statusCode < 300) {
                              statusColor = AppColors.running;
                            } else if (entry.statusCode < 500) {
                              statusColor = AppColors.warning;
                            } else {
                              statusColor = AppColors.error;
                            }

                            final clientShort = entry.clientAddress != null
                                ? '(${entry.clientAddress!.substring(0, 6)}...${entry.clientAddress!.substring(entry.clientAddress!.length - 4)})'
                                : '';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Consolas',
                                    color: colors.textMuted,
                                  ),
                                  children: [
                                    TextSpan(text: '[$time] '),
                                    TextSpan(
                                      text: entry.method,
                                      style: TextStyle(
                                        color: methodColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(text: ' ${entry.path} '),
                                    TextSpan(
                                      text: '${entry.statusCode}',
                                      style: TextStyle(color: statusColor),
                                    ),
                                    if (clientShort.isNotEmpty)
                                      TextSpan(text: ' $clientShort'),
                                    if (entry.error != null)
                                      TextSpan(
                                        text: ' ${entry.error}',
                                        style: TextStyle(color: AppColors.error),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppTextStyles styles, AppColorScheme colors) {
    return Container(
      height: 36 * styles.scale,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.api, color: colors.textMuted, size: 16),
          const SizedBox(width: 8),
          Text('API', style: AppTheme.bodyNormal.copyWith(color: colors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildSection({
    required AppColorScheme colors,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(icon, size: 14, color: colors.textMuted),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}
