part of 'publication_worker_runtime.dart';

extension _PublicationResources on _PublicationOwner {
  Future<PublicationResponse> _planResources(
    PlanPublicationResources request,
  ) async {
    final section = _book!.sections[request.index];
    _work(PublicationWorkerWork.sectionParse);
    final document = request.index == _firstIndex
        ? _firstDocument!
        : _book!.loadSection(request.index);
    final references = await discoverPublicationResources(
      _archive!,
      _book!.package,
      section.item,
      _discoveryCheckpoint,
    );
    _work(PublicationWorkerWork.sectionStyle);
    final styled = const CssStyleResolver().resolve(
      _book!,
      request.index,
      document,
      request.settings,
    );
    final lengths = <String, int>{};
    for (final reference in references) {
      if (reference.path case final path? when reference.present) {
        final size = _archive!.size(path);
        if (size > bootstrap.maxResourceBytes) {
          throw const PublicationWorkerException(
            PublicationWorkerFailure.resourceTooLarge,
          );
        }
        lengths[path] = size;
      }
    }
    return PublicationResourcesPlanned(
      request.id,
      request.tag,
      request.generation,
      PublicationSectionResourcePlan(
        sectionIndex: request.index,
        href: section.item.href,
        cfiBase: section.spine.cfiBase,
        document: document,
        styled: PublicationSectionStyles(styled, document.nodes.length),
        references: references,
        lengths: lengths,
      ),
    );
  }

  Future<PublicationResponse> _preloadResources(
    PreloadPublicationResources request,
  ) async {
    var total = 0;
    // Check the entire batch before expanding even its first entry.
    for (final entry in request.lengths.entries) {
      if (entry.value < 0 ||
          entry.value > bootstrap.maxResourceBytes ||
          !_archive!.contains(entry.key) ||
          _archive!.size(entry.key) != entry.value) {
        throw const PublicationWorkerException(
          PublicationWorkerFailure.resourceTooLarge,
        );
      }
      total += entry.value;
      if (total > ReaderResourceBudget.defaultMaxBytes) {
        throw const ReaderResourceException(
          ReaderResourceFailure.budgetExceeded,
        );
      }
    }
    final result = <String, TransferableTypedData>{};
    for (final entry in request.lengths.entries) {
      _work(PublicationWorkerWork.resourceRead);
      final bytes = _archive!.bytes(entry.key);
      if (bytes == null || bytes.length != entry.value) {
        throw const PublicationWorkerException(
          PublicationWorkerFailure.protocol,
        );
      }
      result[entry.key] = TransferableTypedData.fromList([bytes]);
      final hooks = bootstrap.hooks;
      if (hooks?.pausePreload ?? false) {
        final gate = ReceivePort();
        try {
          hooks!.events.send(PublicationWorkerPreloadEvent(gate.sendPort));
          await gate.first;
        } finally {
          gate.close();
        }
      } else {
        await Future<void>.delayed(Duration.zero);
      }
    }
    return PublicationResourcesPreloaded(
      request.id,
      request.tag,
      request.generation,
      result,
    );
  }
}
