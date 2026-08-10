import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';

import '../../diagnostics/diagnostic_codes.dart';
import '../../model/module_location.dart';
import '../base/dependency_rule.dart';

/// Enforces the dependency direction between architectural layers.
///
/// This one rule replaces `pulse_no_domain_import_in_presentation`,
/// `pulse_no_infrastructure_import_in_domain` and
/// `pulse_no_presentation_import_in_domain`: each of those was a single cell of
/// the matrix that lives in `PulseArchitecture.allowedLayerDependencies`, and
/// running them alongside the matrix produced two diagnostics for one bad
/// import.
class LayerDependencyDirection extends DependencyRule {
  static const LintCode code = PulseDiagnosticCodes.invalidLayerDependency;

  LayerDependencyDirection({super.architecture})
      : super(
          name: 'pulse_invalid_layer_dependency',
          description:
              'Enforces the allowed dependency direction between layers.',
        );

  @override
  LintCode get diagnosticCode => code;

  @override
  void checkDependency({
    required Directive node,
    required ModuleLocation source,
    required Uri target,
  }) {
    final sourceLayer = source.layer;
    if (sourceLayer == null) return;

    final destination = ModuleLocation.parse(target, architecture);

    // Cross-package dependencies are governed by the external dependency rule.
    if (destination == null || destination.package != source.package) return;

    final targetLayer = destination.layer;
    if (targetLayer == null) return;

    if (architecture.allowsLayerDependency(
      from: sourceLayer,
      to: targetLayer,
    )) {
      return;
    }

    reportAtNode(node, arguments: [sourceLayer, targetLayer]);
  }
}
