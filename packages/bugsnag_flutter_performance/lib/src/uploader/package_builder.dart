import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:bugsnag_flutter_performance/src/span.dart';
import 'package:bugsnag_flutter_performance/src/uploader/model/otlp_package.dart';
import 'package:crypto/crypto.dart';
import '../configuration.dart';
import '../extensions/resource_attributes.dart';

const int _minSizeForGzip = 128;

abstract class PackageBuilder {
  Future<OtlpPackage> build(
    List<BugsnagPerformanceSpan> spans,
  );
  Future<OtlpPackage> buildEmptyPackage();
  void setConfig(BugsnagPerformanceConfiguration? config);
}

class PackageBuilderImpl implements PackageBuilder {
  final ResourceAttributesProvider attributesProvider;
  BugsnagPerformanceConfiguration? _config;
  PackageBuilderImpl({
    required this.attributesProvider,
  });

  @override
  Future<OtlpPackage> build(List<BugsnagPerformanceSpan> spans) async {
    var payload = await _buildPayload(spans: spans);
    var isZipped = false;
    final uncompressedData = payload;
    if (payload.length >= _minSizeForGzip) {
      payload = GZipCodec().encode(payload);
      isZipped = true;
    }
    final headers = _buildHeaders(
      spans: spans,
      payload: uncompressedData,
      isZipped: isZipped,
    );
    return OtlpPackage(
      headers: headers,
      payload: Uint8List.fromList(payload),
    );
  }

  @override
  Future<OtlpPackage> buildEmptyPackage() async {
    final payload = utf8.encode(jsonEncode({'resourceSpans': []}));
    final headers = {
      'Content-Type': 'application/json',
      'Bugsnag-Integrity': _integrityDigestForData(payload: payload),
      'Bugsnag-Span-Sampling': '1:0',
    };
    return OtlpPackage(
      headers: headers,
      payload: Uint8List.fromList(payload),
    );
  }

  Future<List<int>> _buildPayload({
    required List<BugsnagPerformanceSpan> spans,
  }) async {
    final jsonList = spans.map((span) => span.toJson()).toList();
    final jsonRequest = {
      'resourceSpans': [
        {
          'scopeSpans': [
            {
              'spans': jsonList,
            }
          ],
          'resource': {
            'attributes': await attributesProvider.resourceAttributes(_config)
          },
        }
      ]
    };
    final json = jsonEncode(jsonRequest);
    return utf8.encode(json);
  }

  Map<String, String> _buildHeaders({
    required List<BugsnagPerformanceSpan> spans,
    required List<int> payload,
    required bool isZipped,
  }) {
    return {
      'Content-Type': 'application/json',
      'Bugsnag-Integrity': _integrityDigestForData(payload: payload),
      'Bugsnag-Uncompressed-Content-Length': payload.length.toString(),
      'Bugsnag-Span-Sampling': _samplingHeaderValue(spans: spans),
      if (isZipped) 'Content-Encoding': 'gzip'
    };
  }

  String _integrityDigestForData({
    required List<int> payload,
  }) {
    return 'sha1 ${sha1.convert(payload)}';
  }

  String _samplingHeaderValue({
    required List<BugsnagPerformanceSpan> spans,
  }) {
    Map<double, int> spansWithProbability = {};
    for (var span in spans) {
      if (span is BugsnagPerformanceSpanImpl) {
        final samplingProbability = span.attributes.samplingProbability;
        if (samplingProbability != null) {
          final spansCount = spansWithProbability[samplingProbability] ?? 0;
          spansWithProbability[samplingProbability] = spansCount + 1;
        }
      }
    }

    return spansWithProbability.entries
        .map((e) =>
            '${e.key.toStringAsFixed(2).replaceFirst('0.', '.').replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "")}:${e.value}')
        .join(';');
  }

  @override
  void setConfig(BugsnagPerformanceConfiguration? config) {
    _config = config;
  }
}
