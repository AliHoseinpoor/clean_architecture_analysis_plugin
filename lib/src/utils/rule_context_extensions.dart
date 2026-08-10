import 'package:analyzer/analysis_rule/rule_context.dart';

import '../config/pulse_architecture.dart';
import '../model/module_location.dart';

extension RuleContextLocation on RuleContext {
  /// Where the library currently being analysed sits in the architecture, or
  /// `null` if it is outside `lib/` or outside the known project structure.
  ModuleLocation? locationIn(PulseArchitecture architecture) {
    final uri = libraryElement?.uri;
    if (uri == null) return null;

    return ModuleLocation.parse(uri, architecture);
  }

  /// Whether the unit currently being visited is the library's own defining
  /// file, as opposed to a `part`.
  ///
  /// Rules that reason about *file names* need this: a `part` has a different
  /// file name from the library that owns it, and reporting the library's
  /// convention against a part's name produces nonsense.
  bool isDefiningUnitOf(ModuleLocation location) {
    return currentUnit?.file.shortName == location.fileName;
  }
}
