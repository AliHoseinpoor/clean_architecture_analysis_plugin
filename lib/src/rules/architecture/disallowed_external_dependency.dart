import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';

import '../../diagnostics/diagnostic_codes.dart';
import '../../model/module_location.dart';
import '../../utils/directive_target.dart';
import '../base/dependency_rule.dart';

/// Keeps frameworks and third-party SDKs out of the inner layers.
///
/// This is the rule the original plugin was missing, and in practice it catches
/// more real architecture violations than all the layer rules combined. The
/// layer rules only look at your own package, so nothing stopped a domain
/// entity from importing `package:flutter/material.dart`, `package:dio/dio.dart`
/// or `package:cloud_firestore/…` — each of which nails the domain to a
/// framework far more firmly than a stray internal import ever could.
///
/// The policy is an allow-list per layer
/// ([PulseArchitecture.allowedExternalDependencies]) rather than a deny-list:
/// a deny-list has to be updated every time someone adds a dependency, an
/// allow-list defaults to safe.
class DisallowedExternalDependency extends DependencyRule {
  static const LintCode code =
      PulseDiagnosticCodes.disallowedExternalDependency;

  DisallowedExternalDependency({super.architecture})
      : super(
          name: 'pulse_disallowed_external_dependency',
          description:
              'Prevents inner layers from depending on frameworks and '
              'third-party packages.',
        );

  @override
  LintCode get diagnosticCode => code;

  @override
  void checkDependency({
    required Directive node,
    required ModuleLocation source,
    required Uri target,
  }) {
    final layer = source.layer;
    if (layer == null) return;

    // Dependencies inside the same package are the layer rule's business.
    if (target.scheme == 'package' &&
        target.pathSegments.isNotEmpty &&
        target.pathSegments.first == source.package) {
      return;
    }

    final identifier = externalDependencyIdentifierOf(target);
    if (identifier == null) return;

    if (architecture.allowsExternalDependency(
      layer: layer,
      identifier: identifier,
    )) {
      return;
    }

    reportAtNode(node, arguments: [layer, identifier]);
  }
}
