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
    final running =
        _phase == _TestPhase.latency ||
        _phase == _TestPhase.download ||
        _phase == _TestPhase.upload;
    final current = _phase == _TestPhase.download
        ? _download
        : _phase == _TestPhase.upload
        ? _upload
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Internet speed test',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: running ? null : 1,
                    strokeWidth: 8,
                    color: colorScheme.primary.withValues(alpha: .18),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      current == null ? '—' : current.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('Mbps'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _status,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _phase == _TestPhase.error ? colorScheme.error : null,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Metric(
                label: 'PING',
                value: _ping == null ? '—' : '${_ping!.toStringAsFixed(0)} ms',
                icon: Icons.network_ping,
              ),
              _Metric(
                label: 'DOWNLOAD',
                value: _download == null
                    ? '—'
                    : '${_download!.toStringAsFixed(1)} Mbps',
                icon: Icons.download,
              ),
              _Metric(
                label: 'UPLOAD',
                value: _upload == null
                    ? '—'
                    : '${_upload!.toStringAsFixed(1)} Mbps',
                icon: Icons.upload,
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: running ? null : _run,
            icon: Icon(
              _phase == _TestPhase.done || _phase == _TestPhase.error
                  ? Icons.refresh
                  : Icons.speed,
            ),
            label: Text(
              _phase == _TestPhase.done || _phase == _TestPhase.error
                  ? 'Run again'
                  : 'Start test',
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 4),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      Text(value, style: Theme.of(context).textTheme.labelLarge),
    ],
  );
}
