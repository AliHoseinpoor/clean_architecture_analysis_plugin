import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';

import '../../config/pulse_architecture.dart';
import '../../diagnostics/diagnostic_codes.dart';
import '../../model/module_location.dart';
import '../base/dependency_rule.dart';

/// Keeps features from reaching into each other's internals.
///
/// The original version forbade *all* cross-feature imports, which is a policy
/// that tends to collapse in practice: the moment checkout needs the current
/// user, teams either disable the rule or start copying types. The default here
/// is [CrossFeatureAccess.publicApiOnly] — a feature may be used through its
/// barrel file (`lib/features/<feature>/<feature>.dart`) and nothing else. That
/// gives a feature a real public API and keeps refactoring freedom behind it.
///
/// Set `crossFeatureAccess: CrossFeatureAccess.forbidden` in
/// [PulseArchitecture] to restore the stricter behaviour.
class NoCrossFeatureImport extends DependencyRule {
  static const LintCode code = PulseDiagnosticCodes.noCrossFeatureImport;

  NoCrossFeatureImport({super.architecture})
      : super(
          name: 'pulse_no_cross_feature_import',
          description:
              'Prevents a feature from depending on the internals of another '
              'feature.',
        );

  @override
  LintCode get diagnosticCode => code;

  @override
  void checkDependency({
    required Directive node,
    required ModuleLocation source,
    required Uri target,
  }) {
    final sourceFeature = source.feature;
    if (sourceFeature == null) return;

    final destination = ModuleLocation.parse(target, architecture);
    if (destination == null || destination.package != source.package) return;

    final targetFeature = destination.feature;
    if (targetFeature == null || targetFeature == sourceFeature) return;

    final isPublicApi =
        architecture.crossFeatureAccess == CrossFeatureAccess.publicApiOnly &&
            destination.isFeatureBarrel;
    if (isPublicApi) return;

    reportAtNode(node, arguments: [sourceFeature, targetFeature]);
  }
}
