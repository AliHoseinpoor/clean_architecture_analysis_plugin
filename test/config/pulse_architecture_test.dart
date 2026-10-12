import 'package:clean_architecture_analysis_plugin/src/config/pulse_architecture.dart';
import 'package:test/test.dart';

void main() {
  const architecture = PulseArchitecture.instance;

  group('presentation -> domain', () {
    test('allows operation errors and value objects', () {
      expect(architecture.allowsLayerDependency(from: 'presentation', to: 'domain', targetFolder: 'errors'), isTrue);
      expect(
        architecture.allowsLayerDependency(from: 'presentation', to: 'domain', targetFolder: 'value_objects'),
        isTrue,
      );
    });

    test('forbids entities, repositories, services and loose files', () {
      for (final folder in ['entities', 'repositories', 'services', null]) {
        expect(
          architecture.allowsLayerDependency(from: 'presentation', to: 'domain', targetFolder: folder),
          isFalse,
          reason: 'domain/${folder ?? '<file>'}',
        );
      }
    });
  });

  test('restrictions narrow only the listed pair', () {
    expect(architecture.allowsLayerDependency(from: 'application', to: 'domain', targetFolder: 'entities'), isTrue);
    expect(architecture.allowsLayerDependency(from: 'presentation', to: 'application'), isTrue);
    expect(architecture.allowsLayerDependency(from: 'presentation', to: 'infrastructure'), isFalse);
    expect(architecture.allowsLayerDependency(from: 'domain', to: 'application'), isFalse);
  });

  test('application may use the injectable and freezed annotations, domain may not', () {
    expect(architecture.allowsExternalDependency(layer: 'application', identifier: 'package:injectable'), isTrue);
    expect(
      architecture.allowsExternalDependency(layer: 'application', identifier: 'package:freezed_annotation'),
      isTrue,
    );
    expect(architecture.allowsExternalDependency(layer: 'application', identifier: 'package:flutter'), isFalse);
    expect(architecture.allowsExternalDependency(layer: 'domain', identifier: 'package:injectable'), isFalse);
    expect(architecture.allowsExternalDependency(layer: 'domain', identifier: 'package:freezed_annotation'), isFalse);
  });
}
