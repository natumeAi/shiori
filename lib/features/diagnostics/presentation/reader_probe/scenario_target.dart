/// Probe control plane; pointer actions are always injected by the runner.
abstract interface class ScenarioTarget {
  int get sectionCount;
  int get pageCount;
  bool get atEnd;
  Future<void> jump(int section, {int page = 0, bool cold = false});
  Future<void> longParagraph();
  Future<void> largeText();
  Future<void> warm();
  void holdPreparation();
  void releasePreparation();
  void suspend();
  Future<void> resume();
  void snapshot();
}
