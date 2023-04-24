import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

const _modelStr = r"\w+\.?\w+";
const _insideCurlyBraces = "{$_modelStr}";
final _modelPattern = RegExp(_modelStr);
final _modelSlotPattern = RegExp(_insideCurlyBraces);

mixin LabelReplacer {
  Map<String, String> get labelMap;
  String textFrom(String key, ModelLabeler? labeler) {
    try {
      return convertTextWithLabels(labelMap[key]!, labeler);
    } catch (e) {
      _reportError(e, desc: "Cannot get text of key: $key");
      return key;
    }
  }

  static String convertTextWithLabels(String text, ModelLabeler? labeler) {
    try {
      return text.splitMapJoin(
        _modelSlotPattern,
        onMatch: (modelMatch) {
          final labelKey = _modelPattern.allMatches(modelMatch[0]!).single[0]!;
          if (labeler == null) {
            _reportError(Exception("Cannot properly convert text: $text"),
                desc: "ModelLabeler is absence but found label key($labelKey)");
            return labelKey;
          }
          return labeler.getModelLabel(labelKey);
        },
      );
    } catch (e) {
      _reportError(e, desc: "Cannot convert text: $text");
      return text;
    }
  }
}

@immutable
mixin LabeledModel {
  String get mainKey;
  String get defaultLabel;

  String? getLabel(String subKey);
  String _getLabel(String? subKey) {
    if (subKey == null) return defaultLabel;
    return getLabel(subKey) ?? defaultLabel;
  }
}

@immutable
mixin ModelLabeler {
  LabeledModel getModel(String modelKey);
  String getModelLabel(String key) {
    final split = key.split(".");
    final modelKey = split.first;
    try {
      final model = getModel(modelKey);
      final subKey = split.elementAtOrNull(1);
      return model._getLabel(subKey);
    } catch (e) {
      _reportError(e, desc: "Cannot get model label from model_key: $key");
      return key;
    }
  }

  @override
  operator ==(Object? other);
}

abstract class ModelLabelerScope<T extends ModelLabeler>
    extends InheritedWidget {
  const ModelLabelerScope(
      {super.key, required this.model, required super.child});
  final T model;
  @override
  bool updateShouldNotify(covariant ModelLabelerScope oldWidget) =>
      oldWidget.model != model;
}

class LabelScope extends InheritedWidget with LabelReplacer {
  const LabelScope({super.key, required this.labelMap, required super.child});
  @override
  final Map<String, String> labelMap;

  @override
  bool updateShouldNotify(covariant LabelScope oldWidget) =>
      oldWidget.labelMap != labelMap;
}

/// [LabelScope] 찾지 못하고 null 반환시 FatalError 일으켜야함.
/// 즉, 이를 시스템에 도입하면 top level에 [LabelScope]하나를 두는게 원칙임.
class Labeler<T extends ModelLabelerScope> extends StatelessWidget {
  const Labeler(String this.labelKey, {super.key, this.style}) : text = null;
  const Labeler.text(String this.text, {super.key, this.style})
      : labelKey = null;

  final String? labelKey;
  final String? text;
  final TextStyle? style;
  String getText(BuildContext context) {
    assert(labelKey != null || text != null);
    final modelLabeler = context.dependOnInheritedWidgetOfExactType<T>()?.model;
    if (labelKey == null) {
      return LabelReplacer.convertTextWithLabels(text!, modelLabeler);
    }
    return context
        .dependOnInheritedWidgetOfExactType<LabelScope>()! //<- 의도된 null checker
        .textFrom(labelKey!, modelLabeler);
  }

  @override
  Widget build(BuildContext context) => Text(getText(context), style: style);
}

void _reportError(Object e,
        {StackTrace? st,
        Iterable<String> Function(Iterable<String>)? stackFilter,
        String? lib,
        String? desc}) =>
    FlutterError.reportError(FlutterErrorDetails(
      exception: e,
      stack: st,
      stackFilter: stackFilter,
      library: lib,
      context: desc == null ? null : ErrorDescription(desc),
    ));
