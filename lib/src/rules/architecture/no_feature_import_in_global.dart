import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';

import '../../diagnostics/diagnostic_codes.dart';
import '../../model/module_location.dart';
import '../base/dependency_rule.dart';

/// Keeps global modules (`core`, `shared`, `design_system`, ...) free of
/// feature dependencies.
///
/// This is the rule that protects the *acyclic* part of the architecture: once
/// `core` imports a feature, every feature transitively depends on that one,
/// and module boundaries stop meaning anything.
///
/// `bootstrap` is a deliberate exception in most projects — it is the
/// composition root and has to see every feature to wire them together. If your
/// `bootstrap` lives under `lib/bootstrap/`, remove it from
/// `PulseArchitecture.globalModules`, or exclude the folder in
/// `analysis_options.yaml`.
class NoFeatureImportInGlobal extends DependencyRule {
  static const LintCode code = PulseDiagnosticCodes.noFeatureImportInGlobal;

  NoFeatureImportInGlobal({super.architecture})
    : super(
        name: 'pulse_no_feature_import_in_global',
        description: 'Prevents global modules from depending on features.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void checkDependency({required Directive node, required ModuleLocation source, required Uri target}) {
    final globalModule = source.globalModule;
    if (globalModule == null) return;

    // The Composition Root is allowed to depend on Features because it is
    // responsible for assembling and wiring the application.
    if (source.isCompositionRoot(architecture)) {
      return;
    }

    final destination = ModuleLocation.parse(target, architecture);
    if (destination == null || destination.package != source.package) return;

    final targetFeature = destination.feature;
    if (targetFeature == null) return;

    reportAtNode(node, arguments: [globalModule, targetFeature]);
  }
}
