import 'dart:io';
import 'package:bugsnag_flutter_performance/src/uploader/sampler.dart';
import 'package:bugsnag_flutter_performance/src/uploader/uploader_client.dart';
import 'package:bugsnag_flutter_performance/src/uploader/model/otlp_package.dart';
import 'package:bugsnag_flutter_performance/src/util/clock.dart';

abstract class Uploader {
  Future<RequestResult> upload({required OtlpPackage package});
}

enum RequestResult {
  success,
  retriableFailure,
  permanentFailure,
}

class UploaderImpl implements Uploader {
  final String apiKey;
  final Uri url;
  final UploaderClient client;
  final BugsnagClock clock;
  final Sampler sampler;
  UploaderImpl({
    required this.apiKey,
    required this.url,
    required this.client,
    required this.clock,
    required this.sampler,
  });

  @override
  Future<RequestResult> upload({
    required OtlpPackage package,
  }) async {
    final sentAtTime = clock.now().toUtc();
    var headers = {
      'Bugsnag-Api-Key': apiKey,
      'Bugsnag-Sent-At': sentAtTime
          .subtract(Duration(microseconds: sentAtTime.microsecond))
          .toIso8601String(),
    };
    headers.addAll(package.headers);
    try {
      final request = await client.post(url: url);
      request.setHeaders(headers);
      request.setBody(package.payload);
      final response = await request.send();
      sampler.handleResponseHeaders(response.headers);
      return _getResult(response.statusCode);
    } on SocketException catch (_) {
      return RequestResult.retriableFailure;
    } catch (_) {
      return RequestResult.permanentFailure;
    }
  }

  RequestResult _getResult(int statusCode) {
    switch (statusCode) {
      case 200:
      case 202:
        return RequestResult.success;
      case 0:
      case 408:
      case 429:
        return RequestResult.retriableFailure;
      default:
        return statusCode >= 500
            ? RequestResult.retriableFailure
            : RequestResult.permanentFailure;
    }
  }
}
