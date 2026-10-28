import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';
import 'package:shiori/features/reader/engine/support/unsupported_layout.dart';

void main() {
  OffendingConstruct construct() => OffendingConstruct(
    kind: CapabilityConstructKind.svg,
    identifier: 'required-filter',
    nodeIndex: 4,
  );

  test('complete/malformed/unsupported/resource/render remain distinct', () {
    final verdicts = <SectionCapability>[
      CompleteSectionCapability(sectionIndex: 0, reason: 'complete'),
      MalformedSectionCapability(
        sectionIndex: 0,
        reason: 'invalid',
        constructs: [construct()],
      ),
      UnsupportedSectionCapability(
        sectionIndex: 0,
        reason: 'outside-profile',
        constructs: [construct()],
      ),
      ResourceSectionCapability(
        sectionIndex: 0,
        reason: 'budget',
        constructs: [construct()],
      ),
      RenderSectionCapability(
        sectionIndex: 0,
        reason: 'paint-failed',
        constructs: [construct()],
      ),
    ];
    String classify(SectionCapability verdict) => switch (verdict) {
      CompleteSectionCapability() => 'complete',
      MalformedSectionCapability() => 'malformed',
      UnsupportedSectionCapability() => 'unsupported',
      ResourceSectionCapability() => 'resource',
      RenderSectionCapability() => 'render',
    };
    expect(verdicts.map(classify), [
      'complete',
      'malformed',
      'unsupported',
      'resource',
      'render',
    ]);
    expect(verdicts.map((v) => v.isComplete), [
      true,
      false,
      false,
      false,
      false,
    ]);
    expect(
      MalformedSectionCapability(
        sectionIndex: 0,
        reason: 'same',
        constructs: [construct()],
      ),
      isNot(
        RenderSectionCapability(
          sectionIndex: 0,
          reason: 'same',
          constructs: [construct()],
        ),
      ),
    );
  });

  test('fixed metadata alone never creates an unsupported verdict', () {
    final fixed = OffendingConstruct(
      kind: CapabilityConstructKind.fixedMetadata,
      identifier: 'rendition:layout',
    );
    expect(
      () => UnsupportedSectionCapability(
        sectionIndex: 0,
        reason: 'fixed',
        constructs: [fixed],
      ),
      throwsArgumentError,
    );
    expect(
      () => UnsupportedSectionCapability(
        sectionIndex: 0,
        reason: 'fixed',
        constructs: [construct()],
        layoutReason: UnsupportedLayoutReason.fixedLayout,
      ),
      throwsArgumentError,
    );
    final vertical = UnsupportedSectionCapability(
      sectionIndex: 0,
      reason: 'vertical',
      constructs: [
        fixed,
        OffendingConstruct(
          kind: CapabilityConstructKind.layout,
          identifier: 'writing-mode',
        ),
      ],
      layoutReason: UnsupportedLayoutReason.verticalWritingMode,
    );
    expect(vertical.layoutReason, UnsupportedLayoutReason.verticalWritingMode);
  });

  test('failure requires a reason, section and offending constructs', () {
    expect(
      () => CompleteSectionCapability(sectionIndex: -1, reason: 'complete'),
      throwsArgumentError,
    );
    expect(
      () => CompleteSectionCapability(sectionIndex: 0, reason: ''),
      throwsArgumentError,
    );
    expect(
      () => MalformedSectionCapability(
        sectionIndex: 0,
        reason: 'bad',
        constructs: [],
      ),
      throwsArgumentError,
    );
    expect(
      () =>
          OffendingConstruct(kind: CapabilityConstructKind.css, identifier: ''),
      throwsArgumentError,
    );
    expect(
      () => OffendingConstruct(
        kind: CapabilityConstructKind.css,
        identifier: 'x',
        nodeIndex: -1,
      ),
      throwsArgumentError,
    );
  });

  test('capability values deeply copy constructs and use value equality', () {
    final constructs = [construct()];
    final a = RenderSectionCapability(
      sectionIndex: 0,
      reason: 'failed',
      constructs: constructs,
    );
    final b = RenderSectionCapability(
      sectionIndex: 0,
      reason: 'failed',
      constructs: [construct()],
    );
    constructs.clear();
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.constructs.single, construct());
    expect(() => a.constructs.clear(), throwsUnsupportedError);
    expect(
      CompleteSectionCapability(sectionIndex: 0, reason: 'complete').constructs,
      isEmpty,
    );
  });
}
