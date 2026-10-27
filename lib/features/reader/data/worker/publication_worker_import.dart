part of 'publication_worker_runtime.dart';

extension _PublicationImport on _PublicationOwner {
  Future<PublicationResponse> _prepare(PreparePublication request) async {
    if (!request.identity.isCurrent ||
        request.identity.canonicalVersion != canonicalTextVersion) {
      throw const PublicationWorkerException(
        PublicationWorkerFailure.incompatibleIdentity,
      );
    }
    close();
    var failure = PublicationImportFailure.invalidArchive;
    try {
      _work(PublicationWorkerWork.archiveOpen);
      final archive = _archive = EpubArchive.openFile(
        request.path,
        limits: bootstrap.limits,
      );
      failure = PublicationImportFailure.invalidPackage;
      _work(PublicationWorkerWork.packageParse);
      final container = parseXmlDocument(
        archive.text('META-INF/container.xml') ?? '',
      ).documentElement;
      if (container?.localName != 'container' ||
          container?.namespaceUri != containerNamespace) {
        throw const FormatException();
      }
      final package = readEpubPackage(archive);
      final book = _book = EpubBook.fromArchive(archive, package);
      final snapshot = PublicationSnapshot(package);
      final metadata = importMetadata(archive, package.opfPath);
      final first = package.spine.where((item) => item.isLinear).firstOrNull;
      final index = first == null
          ? -1
          : book.sections.indexWhere(
              (section) => identical(section.spine, first),
            );
      if (index < 0) throw const FormatException();
      failure = PublicationImportFailure.invalidFirstSection;
      final section = book.sections[index];
      if (!{
        xhtmlMediaType,
        htmlMediaType,
        svgMediaType,
      }.contains(section.item.mediaType)) {
        throw const FormatException();
      }
      _work(PublicationWorkerWork.sectionParse);
      final document = book.loadSection(index);
      final root = document.node(document.documentElementIndex);
      if (section.item.mediaType == svgMediaType) {
        if (root.localName != 'svg' ||
            root.namespaceUri != 'http://www.w3.org/2000/svg') {
          throw const FormatException();
        }
      } else if (root.localName != 'html' ||
          root.namespaceUri != 'http://www.w3.org/1999/xhtml') {
        throw const FormatException();
      }
      _work(PublicationWorkerWork.sectionStyle);
      final facts = importLayoutFacts(book, metadata, index, document);
      _work(PublicationWorkerWork.canonicalIndex);
      final canonical = CanonicalIndex.build(document);
      final resources = await discoverPublicationResources(
        archive,
        package,
        section.item,
        _discoveryCheckpoint,
      );
      _firstDocument = document;
      _firstIndex = index;
      _tag = request.tag;
      _generation = request.generation;
      return PublicationPrepared(
        request.id,
        request.tag,
        request.generation,
        PreparedPublication(
          identity: request.identity,
          snapshot: snapshot,
          metadata: metadata,
          layoutFacts: facts,
          firstSection: FirstSectionReadiness(
            sectionIndex: index,
            href: section.item.href,
            cfiBase: section.spine.cfiBase,
            parserUsed: document.parserUsed,
            parserErrorClass: document.parserErrorClass,
            canonicalVersion: canonical.version,
            canonicalLength: canonical.length,
            canonicalSignature: canonical.signature,
            resources: resources,
          ),
        ),
      );
    } on Object {
      close();
      throw PublicationImportException(failure);
    }
  }

  Future<void> _discoveryCheckpoint() async {
    _work(PublicationWorkerWork.resourceDiscovery);
    final hooks = bootstrap.hooks;
    if (hooks?.pauseDiscovery ?? false) {
      final gate = ReceivePort();
      try {
        hooks!.events.send(PublicationWorkerDiscoveryEvent(gate.sendPort));
        await gate.first;
      } finally {
        gate.close();
      }
    } else {
      // A synchronous parse/inflate remains indivisible, as in open/load.
      await Future<void>.delayed(Duration.zero);
    }
  }
}
