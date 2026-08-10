import 'package:analyzer/dart/ast/ast.dart';

/// Resolves the canonical URI a directive points at.
///
/// Two strategies, in order:
///
/// 1. **The element model.** `libraryImport.importedLibrary.uri` is the
///    canonical URI of the imported library, which means a relative import
///    (`../domain/user.dart`) and a package import
///    (`package:pulse/features/auth/domain/user.dart`) both come back in the
///    same normalised form. It also handles the package config, so the plugin
///    never needs to know the project's package name — which is exactly what
///    makes it reusable across projects.
///
/// 2. **Syntactic resolution**, for imports the analyzer could not resolve
///    (a typo, a missing dependency, a file being edited). `Uri.resolve`
///    correctly handles `./x.dart`, `../x.dart` *and* the bare `x/y.dart`
///    form, which naive `startsWith('../')` checks miss.
///
/// Returns `null` when neither strategy produces a URI.
///
/// If a future analyzer release renames `libraryImport`/`libraryExport`, this
/// function is the single place to update.
Uri? resolveDirectiveTarget({
  required Directive node,
  required Uri libraryUri,
}) {
  final resolved = switch (node) {
    ImportDirective(:final libraryImport) =>
      libraryImport?.importedLibrary?.uri,
    ExportDirective(:final libraryExport) =>
      libraryExport?.exportedLibrary?.uri,
    _ => null,
  };

  if (resolved != null) return resolved;

  if (node is! UriBasedDirective) return null;

  final rawUri = node.uri.stringValue;
  if (rawUri == null || rawUri.isEmpty) return null;

  try {
    return libraryUri.resolve(rawUri);
  } on FormatException {
    return null;
  }
}

/// Normalises a URI to the identifier used by dependency allow-lists:
/// `dart:async`, `package:flutter`, ... Returns `null` for anything else.
String? externalDependencyIdentifierOf(Uri uri) {
  if (uri.scheme == 'dart') return 'dart:${uri.path}';

  if (uri.scheme == 'package' && uri.pathSegments.isNotEmpty) {
    return 'package:${uri.pathSegments.first}';
  }

  return null;
}
