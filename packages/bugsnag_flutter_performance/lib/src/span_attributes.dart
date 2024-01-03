class BugsnagPerformanceSpanAttributes {
  BugsnagPerformanceSpanAttributes({
    this.category = 'custom',
    this.isFirstClass,
    this.samplingProbability = 1.0,
    this.phase,
  });

  final String category;
  final bool? isFirstClass;
  double samplingProbability;
  final String? phase;

  BugsnagPerformanceSpanAttributes.fromJson(dynamic json)
      : category = _value(
              json: json,
              key: 'bugsnag.span.category',
              type: _ParameterType.string,
            ) as String? ??
            'custom',
        isFirstClass = _value(
          json: json,
          key: 'bugsnag.span.first_class',
          type: _ParameterType.bool,
        ) as bool?,
        samplingProbability = _value(
              json: json,
              key: 'bugsnag.sampling.p',
              type: _ParameterType.double,
            ) as double? ??
            1.0,
        phase = _value(
          json: json,
          key: 'bugsnag.phase',
          type: _ParameterType.string,
        ) as String?;

  dynamic toJson() => [
        {
          'key': 'bugsnag.span.category',
          'value': {
            'stringValue': category,
          },
        },
        if (isFirstClass != null)
          {
            'key': 'bugsnag.span.first_class',
            'value': {
              'boolValue': isFirstClass,
            },
          },
        {
          'key': 'bugsnag.sampling.p',
          'value': {
            'doubleValue': samplingProbability,
          },
        },
        if (phase != null)
          {
            'key': 'bugsnag.phase',
            'value': {
              'stringValue': phase,
            }
          }
      ];
}

enum _ParameterType { string, double, bool }

dynamic _value({
  required dynamic json,
  required String key,
  required _ParameterType type,
}) {
  final attributes = json as List<Map<String, dynamic>>?;
  if (attributes == null) {
    return null;
  }
  final entry =
      attributes.where((element) => element['key'] == key).firstOrNull;
  if (entry == null) {
    return null;
  }
  switch (type) {
    case _ParameterType.string:
      return entry['value']['stringValue'];
    case _ParameterType.double:
      return entry['value']['doubleValue'];
    case _ParameterType.bool:
      return entry['value']['boolValue'];
  }
}
