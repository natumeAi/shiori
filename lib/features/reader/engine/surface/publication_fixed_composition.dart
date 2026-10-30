import 'package:shiori/core/config/content_identity.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';
import 'package:shiori/features/reader/data/layout/authored_dimension_resolver.dart';
import 'package:shiori/features/reader/data/layout/reading_unit_section.dart';
import 'package:shiori/features/reader/data/layout/section_rendition.dart';
import 'package:shiori/features/reader/data/layout/section_source_facts.dart';
import 'package:shiori/features/reader/data/layout/source_page_id.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/pagination/anchor.dart';
import 'package:shiori/features/reader/engine/pagination/layout_identity.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';
import 'package:shiori/features/reader/engine/pagination/reading_unit_navigator.dart';
import 'package:shiori/features/reader/engine/pagination/section_preparer.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/pagination/reading_unit_composer.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';
import 'package:shiori/features/reader/engine/surface/page_surface_pool.dart';
import 'package:shiori/features/reader/engine/surface/reflow_section_cache.dart';

/// Real rendition/composition snapshot for one prepared publication.
///
/// Reflow sections use the existing [SectionPreparer] pagination path so their
/// actual layout key/page count feed A1's composer. Fixed sections use their
/// validated rendition and authored dimensions only. No fixed scene is built
/// here and no partial unit is published on failure.
final class PublicationFixedComposition {
  PublicationFixedComposition._(this.navigator, this._reflow, this.documents);
  final ComposedReadingUnitNavigator navigator;
  final ReflowSectionCache _reflow;
  Map<int, PreparedSection> get reflowSections => _reflow.sections;
  final Map<SourcePageId, SourceDocument> documents;

  Future<PreparedSection?> loadReflow(int index) =>
      navigator.sections[index].rendition.isFixed == false
      ? _reflow.load(index)
      : Future.value(null);

  void dispose() {
    _reflow.dispose();
  }

  Future<void> drain() => _reflow.drain();

  static Future<PublicationFixedComposition> prepare({
    required EpubBook book,
    required ContentIdentity identity,
    required PublicationLayoutFacts facts,
    required ReaderSettings settings,
    required double viewportWidth,
    required double viewportHeight,
    required double devicePixelRatio,
    required LayoutIdentity Function(int section) fixedLayout,
    required FontRegistry fonts,
    SectionPreparer? reflowPreparer,
    PageSurfacePool? pool,
    int generation = 0,
  }) async {
    final sections = facts.sections;
    if (sections.length != book.sections.length) {
      throw ArgumentError('Layout facts do not match publication sections');
    }
    final documents = <SourcePageId, SourceDocument>{};
    final preparer = reflowPreparer ?? SectionPreparer(fonts: fonts);
    final reflow = ReflowSectionCache(
      budget: pool?.resourceBudget ?? SceneResourceBudget(),
      prepare: (index) async {
        final document = book.loadSection(index);
        return preparer.prepare(
          PrepareRequest(
            book: book,
            sectionIndex: index,
            document: document,
            styled: const CssStyleResolver().resolve(
              book,
              index,
              document,
              settings,
            ),
            settings: settings,
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight,
            devicePixelRatio: devicePixelRatio,
            contentId: identity.sha256,
            generation: generation,
          ),
        );
      },
    )..pinned = pool?.pinsSection;
    try {
      final inputs = <ReadingUnitSection>[];
      for (var i = 0; i < sections.length; i++) {
        final fact = sections[i];
        final rendition = fact.renditionResolution ?? sectionRendition(book, i);
        final document = book.loadSection(i);
        final page = SourcePageId(
          content: identity,
          sectionIndex: i,
          spineIndex: book.sections[i].spine.sectionIndex,
          stableId: book.sections[i].item.href,
        );
        documents[page] = document;
        final fixed = rendition.isFixed == true;
        if (fixed) {
          final dimensions = resolveAuthoredDimensions(
            source: extractSectionSourceFacts(document),
            packageRendition: rendition.effective,
          );
          inputs.add(
            ReadingUnitSection(
              page: page,
              href: book.sections[i].item.href,
              rendition: rendition,
              layoutKey: fixedLayout(i).key,
              linear: book.sections[i].spine.isLinear,
              dimensions: dimensions,
              directionIssues: fact.directionIssues(
                pageProgressionDirection: facts.pageProgressionDirection,
              ),
            ),
          );
        } else {
          final delivery = (await reflow.borrow(i))!;
          try {
            final section = delivery.section;
            inputs.add(
              ReadingUnitSection(
                page: page,
                href: book.sections[i].item.href,
                rendition: rendition,
                layoutKey: section.identity.key,
                linear: book.sections[i].spine.isLinear,
                reflowPageCount: section.pageCount,
                directionIssues: fact.directionIssues(
                  pageProgressionDirection: facts.pageProgressionDirection,
                ),
              ),
            );
          } finally {
            delivery.release();
          }
        }
      }
      final ComposedReadingUnitNavigator navigator;
      try {
        navigator = ComposedReadingUnitNavigator(
          sections: inputs,
          viewportWidth: viewportWidth,
          viewportHeight: viewportHeight,
          documents: documents,
          locateReflow: (page, position) async {
            final delivery = await reflow.borrow(page.sectionIndex);
            if (delivery == null) return null;
            try {
              return PageAnchors(delivery.section).locate(position)?.pageIndex;
            } finally {
              delivery.release();
            }
          },
        );
      } on UnsupportedDirectionCompositionException catch (error) {
        throw _directionFailure(inputs, error);
      }
      return PublicationFixedComposition._(navigator, reflow, documents);
    } on Object {
      reflow.dispose();
      rethrow;
    }
  }
}

/// Fixed-section layout identity used by both composition and source loading.
LayoutIdentity fixedSectionLayout({
  required ContentIdentity identity,
  required int section,
  required double viewportWidth,
  required double viewportHeight,
  required double devicePixelRatio,
  required ReaderSettings settings,
  int generation = 0,
}) => LayoutIdentity(
  contentId: identity.sha256,
  sectionIndex: section,
  viewportWidth: viewportWidth,
  viewportHeight: viewportHeight,
  devicePixelRatio: devicePixelRatio,
  settings: settings,
  fontSignature: 'fixed',
  generation: generation,
);

/// Reads the fixed layout facts already retained by the prepared publication.
bool hasFixedSections(PublicationLayoutFacts facts) => facts.sections.any(
  (section) => section.resolvedMode == PublicationLayoutMode.fixed,
);

SectionRendition resolveSectionRendition(EpubBook book, int section) =>
    sectionRendition(book, section);

/// Direction refusal is a typed preparation capability failure, raised before
/// any pool or session exists. The composer itself stays unchanged.
FixedPreparationFailure _directionFailure(
  List<ReadingUnitSection> inputs,
  UnsupportedDirectionCompositionException error,
) {
  final section = inputs
      .firstWhere((section) => section.directionIssues.isNotEmpty)
      .page
      .sectionIndex;
  final issues = error.issues.toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return FixedPreparationFailure(
    UnsupportedSectionCapability(
      sectionIndex: section,
      reason: 'Unsupported section direction',
      constructs: [
        for (final issue in issues)
          OffendingConstruct(
            kind: CapabilityConstructKind.layout,
            identifier: 'direction:${issue.name}',
          ),
      ],
    ),
  );
}
