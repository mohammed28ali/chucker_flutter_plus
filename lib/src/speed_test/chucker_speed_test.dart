import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Opens a standalone internet speed test screen.
///
/// Supply URLs for a download file and an upload endpoint that accepts POST
/// requests. The defaults use Cloudflare's public speed test service.
class ChuckerSpeedTest {
  ChuckerSpeedTest._();

  static Future<void> show(
    BuildContext context, {
    String downloadUrl = 'https://speed.cloudflare.com/__down?bytes=25000000',
    String uploadUrl = 'https://speed.cloudflare.com/__up',
    String latencyUrl = 'https://speed.cloudflare.com/__down?bytes=0',
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _SpeedTestPage(
      downloadUrl: downloadUrl,
      uploadUrl: uploadUrl,
      latencyUrl: latencyUrl,
    ),
  );
}

enum _TestPhase { idle, latency, download, upload, done, error }

class _SpeedTestPage extends StatefulWidget {
  const _SpeedTestPage({
    required this.downloadUrl,
    required this.uploadUrl,
    required this.latencyUrl,
  });

  final String downloadUrl;
  final String uploadUrl;
  final String latencyUrl;

  @override
  State<_SpeedTestPage> createState() => _SpeedTestPageState();
}

class _SpeedTestPageState extends State<_SpeedTestPage> {
  _TestPhase _phase = _TestPhase.idle;
  double? _ping;
  double? _download;
  double? _upload;
  String? _error;
  http.Client? _client;

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  Future<void> _run() async {
    _client?.close();
    final client = http.Client();
    _client = client;
    setState(() {
      _phase = _TestPhase.latency;
      _ping = _download = _upload = null;
      _error = null;
    });
    try {
      final ping = await _measurePing(client);
      if (!mounted) return;
      setState(() {
        _ping = ping;
        _phase = _TestPhase.download;
      });
      final download = await _measureDownload(client);
      if (!mounted) return;
      setState(() {
        _download = download;
        _phase = _TestPhase.upload;
      });
      final upload = await _measureUpload(client);
      if (!mounted) return;
      setState(() {
        _upload = upload;
        _phase = _TestPhase.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Speed test failed: $e';
        _phase = _TestPhase.error;
      });
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
    }
  }

  Future<double> _measurePing(http.Client client) async {
    final samples = <double>[];
    for (var i = 0; i < 3; i++) {
      final watch = Stopwatch()..start();
      final response = await client
          .get(Uri.parse(widget.latencyUrl))
          .timeout(const Duration(seconds: 15));
      watch.stop();
      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw http.ClientException(
          'Latency endpoint returned ${response.statusCode}',
        );
      }
      samples.add(watch.elapsedMicroseconds / 1000);
    }
    samples.sort();
    return samples[samples.length ~/ 2];
  }

  Future<double> _measureDownload(http.Client client) async {
    final request = http.Request('GET', Uri.parse(widget.downloadUrl));
    final watch = Stopwatch()..start();
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Download endpoint returned ${response.statusCode}',
      );
    }
    var bytes = 0;
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      bytes += chunk.length;
    }
    watch.stop();
    return _mbps(bytes, watch.elapsed);
  }

  Future<double> _measureUpload(http.Client client) async {
    const size = 5 * 1024 * 1024;
    final payload = List<int>.generate(
      size,
      (i) => (i * 31 + 17) & 0xff,
      growable: false,
    );
    final request = http.Request('POST', Uri.parse(widget.uploadUrl))
      ..bodyBytes = payload
      ..headers['content-type'] = 'application/octet-stream';
    final watch = Stopwatch()..start();
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 60));
    await response.stream.drain<void>();
    watch.stop();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Upload endpoint returned ${response.statusCode}',
      );
    }
    return _mbps(size, watch.elapsed);
  }

  double _mbps(int bytes, Duration duration) =>
      bytes * 8 / math.max(duration.inMicroseconds, 1);

  String get _status => switch (_phase) {
    _TestPhase.idle => 'Ready to check your connection',
    _TestPhase.latency => 'Measuring latency…',
    _TestPhase.download => 'Measuring download…',
    _TestPhase.upload => 'Measuring upload…',
    _TestPhase.done => 'Test complete',
    _TestPhase.error => _error ?? 'Test failed',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final running =
        _phase == _TestPhase.latency ||
        _phase == _TestPhase.download ||
        _phase == _TestPhase.upload;
    final current = _phase == _TestPhase.download
        ? _download
        : _phase == _TestPhase.upload
        ? _upload
        : null;
    final phaseColor = _phase == _TestPhase.error
        ? colorScheme.error
        : const Color(0xFF14B8A6);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.radar_rounded,
                    color: Color(0xFF0D9488),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connection lab',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Network performance',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SpeedHero(
              phase: _phase,
              current: current,
              status: _status,
              color: phaseColor,
              running: running,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'PING',
                    value: _ping == null
                        ? '—'
                        : '${_ping!.toStringAsFixed(0)} ms',
                    icon: Icons.graphic_eq_rounded,
                    accent: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _Metric(
                    label: 'DOWNLOAD',
                    value: _download == null
                        ? '—'
                        : '${_download!.toStringAsFixed(1)} Mbps',
                    icon: Icons.south_rounded,
                    accent: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _Metric(
                    label: 'UPLOAD',
                    value: _upload == null
                        ? '—'
                        : '${_upload!.toStringAsFixed(1)} Mbps',
                    icon: Icons.north_rounded,
                    accent: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            _PhaseTrack(phase: _phase),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: running ? null : _run,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: Icon(
                  _phase == _TestPhase.done || _phase == _TestPhase.error
                      ? Icons.replay_rounded
                      : Icons.bolt_rounded,
                ),
                label: Text(
                  running
                      ? 'Testing your connection…'
                      : _phase == _TestPhase.done || _phase == _TestPhase.error
                      ? 'Run test again'
                      : 'Start speed test',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedHero extends StatelessWidget {
  const _SpeedHero({
    required this.phase,
    required this.current,
    required this.status,
    required this.color,
    required this.running,
  });
  final _TestPhase phase;
  final double? current;
  final String status;
  final Color color;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final speed = current;
    final activePhase = switch (phase) {
      _TestPhase.latency => 'LATENCY',
      _TestPhase.download => 'DOWNLOAD',
      _TestPhase.upload => 'UPLOAD',
      _TestPhase.done => 'COMPLETE',
      _TestPhase.error => 'ISSUE DETECTED',
      _ => 'READY TO TEST',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F292F), Color(0xFF123F40), Color(0xFF145A52)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: running
                      ? const Color(0xFF5EEAD4)
                      : const Color(0xFF34D399),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5EEAD4).withValues(alpha: .8),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Text(
                activePhase,
                style: const TextStyle(
                  color: Color(0xFF99F6E4),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.wifi_tethering_rounded,
                color: Color(0xFF5EEAD4),
                size: 17,
              ),
              const SizedBox(width: 5),
              const Text(
                'LIVE',
                style: TextStyle(
                  color: Color(0xFFCCFBF1),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 172,
            height: 152,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: running
                        ? null
                        : phase == _TestPhase.done
                        ? 1
                        : 0.78,
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    color: running ? color : const Color(0xFF5EEAD4),
                    backgroundColor: Colors.white.withValues(alpha: .13),
                  ),
                ),
                Container(
                  width: 122,
                  height: 122,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .045),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .08),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        speed == null ? '—' : speed.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Mbps',
                        style: TextStyle(
                          color: Color(0xFF99F6E4),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: phase == _TestPhase.error
                  ? const Color(0xFFFECACA)
                  : const Color(0xFFD1FAE5),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseTrack extends StatelessWidget {
  const _PhaseTrack({required this.phase});
  final _TestPhase phase;

  @override
  Widget build(BuildContext context) {
    final active = switch (phase) {
      _TestPhase.latency => 0,
      _TestPhase.download => 1,
      _TestPhase.upload || _TestPhase.done => 2,
      _ => -1,
    };
    const labels = ['Ping', 'Download', 'Upload'];
    const icons = [
      Icons.graphic_eq_rounded,
      Icons.south_rounded,
      Icons.north_rounded,
    ];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= active
                        ? const Color(0xFFCCFBF1)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: Icon(
                    icons[i],
                    size: 14,
                    color: i <= active
                        ? const Color(0xFF0D9488)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    labels[i],
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: i <= active
                          ? const Color(0xFF0D9488)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: i <= active
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (i < labels.length - 1)
            Container(
              width: 15,
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.fromLTRB(9, 10, 8, 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    letterSpacing: .7,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
