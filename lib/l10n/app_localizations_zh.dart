// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get diagnosticsTitle => '设备诊断探针';

  @override
  String get probeSynthetic => 'S1 合成动画采集';

  @override
  String get readerProbeTitle => '阅读器可行性探针';

  @override
  String get readerProbeHelp =>
      '从内置夹具或 Documents 中选择 EPUB。用户书籍仅以 SHA-256 标识。引擎提交不等于物理呈现；原生呈现数据尚未验证。';

  @override
  String get readerProbeControls => '探针控制';

  @override
  String get readerBooks => '选择书籍 / 刷新列表';

  @override
  String readerFixture(String id) {
    return '夹具：$id';
  }

  @override
  String readerUserBook(String digest) {
    return '用户书籍 SHA-256：$digest';
  }

  @override
  String get readerEmpty => '没有可用书籍，请将 EPUB 放入 Documents 后刷新。';

  @override
  String get readerUnsupported => '此书包含固定版式、竖排或从右至左布局，探针无法打开。可选择其他书籍。';

  @override
  String get readerFailure => '无法打开、准备或证明阅读位置，请重试或选择其他书籍。';

  @override
  String get readerFont => '字体';

  @override
  String readerFontName(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'system': '默认',
      'pingfang': '苹方',
      'yahei': '微软雅黑',
      'sans': '黑体',
      'serif': '宋体',
      'kai': '楷体',
      'other': '默认',
    });
    return '$_temp0';
  }

  @override
  String get readerSize => '字号';

  @override
  String get readerLineHeight => '行高';

  @override
  String get readerLetterSpacing => '字距（em）';

  @override
  String get readerHorizontalMargin => '水平附加边距';

  @override
  String get readerVerticalMargin => '垂直附加边距';

  @override
  String get readerTheme => '主题';

  @override
  String readerThemeName(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'light': '明亮',
      'sepia': '柔和',
      'green': '护眼',
      'dark': '深色',
      'other': '主题 $id',
    });
    return '$_temp0';
  }

  @override
  String readerSettingValue(String label, String value) {
    return '$label：$value';
  }

  @override
  String get readerReducedMotion => '减少动态效果';

  @override
  String get readerJump => '跳转章节';

  @override
  String readerSection(int number) {
    return '第 $number 节';
  }

  @override
  String get readerScenario => '场景';

  @override
  String readerScenarioName(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'R01': 'R01 前后各 40 次轻点',
      'R02': 'R02 拖动、快滑、反向和边界回弹',
      'R03': 'R03 按住手指等待冷邻页',
      'R04': 'R04 队列溢出和跳转',
      'R05': 'R05 冷热双向跨章',
      'R06': 'R06 十万字长段落',
      'R07': 'R07 图文和 SVG',
      'R08': 'R08 字号行高重排和锚点恢复',
      'R09': 'R09 运动及准备时模拟后台恢复',
      'R10': 'R10 百次交替翻页和跳转资源采样',
      'R11': 'R11 用户书籍手动阅读至少 50 次',
      'other': '未知场景',
    });
    return '$_temp0';
  }

  @override
  String get readerRepeat => '重复次数（默认 3）';

  @override
  String get readerManual => '手动触摸采集（R11 必须使用用户书籍）';

  @override
  String get readerStart => '开始阅读器采集';

  @override
  String get readerRunning => '正在采集；脚本触摸为注入输入，后台切换为控制器模拟。';

  @override
  String readerPosition(int section, int page, int total) {
    return '第 $section 节 · 第 $page/$total 页';
  }

  @override
  String get readerManualMinimum => 'R11 每本书至少完成 50 次已接受翻页；提前停止的记录保留为不完整证据。';

  @override
  String get readerNativeMode => '原生呈现证据（仅诊断）';

  @override
  String readerNativeModeName(String mode) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'inventory': '系统信息',
      'a1': 'A1 图层提交（无辅助显示链接）',
      'a2': 'A2 图层提交及辅助显示链接',
      'b': 'B 非默认路径的 drawable 呈现',
      'other': '未知',
    });
    return '$_temp0';
  }

  @override
  String diagnosticsBuild(String buildId, String number) {
    return '构建 $buildId · 版本号 $number';
  }

  @override
  String get diagnosticsEvidence =>
      '本探针只记录合成动画的引擎耗时与调度节奏；物理显示帧率及 EPUB 阅读性能尚未验证。请先声明设备设置。';

  @override
  String get diagnosticsDeviceModel => '设备型号（手动填写，可留空）';

  @override
  String get diagnosticsLowPower => '低电量模式（用户声明）';

  @override
  String get diagnosticsLimitRate => '辅助功能 → 动态效果 → 限制帧速率（用户声明）';

  @override
  String get diagnosticsCharging => '正在充电（用户声明）';

  @override
  String get diagnosticsWarm => '手机感觉发热（用户声明）';

  @override
  String get diagnosticsOn => '开 / 是';

  @override
  String get diagnosticsOff => '关 / 否';

  @override
  String get diagnosticsUnknown => '未知';

  @override
  String get diagnosticsStart => '开始采集（最多 15 秒）';

  @override
  String get diagnosticsStop => '停止采集';

  @override
  String get diagnosticsRecording => '正在采集连续运动…';

  @override
  String get diagnosticsDraining => '正在等待延迟的引擎报告…';

  @override
  String get diagnosticsStorageError => '无法读取或保存本地诊断，请重试。';

  @override
  String get diagnosticsExporting => '正在写入诊断文件…';

  @override
  String diagnosticsResult(String runId, int frames, int motion) {
    return '运行 $runId：$frames 个引擎样本，$motion 个运动事件';
  }

  @override
  String get diagnosticsPartial => '部分证据：无法保证最后一批引擎报告已全部到达。未知与溢出状态保留在文件中。';

  @override
  String diagnosticsCadence(String pattern) {
    return '观测到的引擎节奏：$pattern';
  }

  @override
  String get diagnosticsCadence120 => '接近 120 Hz（并非物理呈现证明）';

  @override
  String get diagnosticsCadence60 => '低阶段耗时、接近 60 Hz，与系统限速相符';

  @override
  String get diagnosticsCadenceMixed => '混合节奏，存在超预算阶段';

  @override
  String get diagnosticsCadenceUnknown => '样本不足或结果不确定';

  @override
  String diagnosticsExported(String path) {
    return '已写入：$path';
  }

  @override
  String get diagnosticsExport => '写入 / 重试导出文件';

  @override
  String get diagnosticsCopy => '复制简短摘要';

  @override
  String get diagnosticsCopied => '摘要已复制；原始证据请从文件取回';

  @override
  String get diagnosticsMotion => '连续变换的合成诊断画面';

  @override
  String get diagnosticsMarkerHelp =>
      '填写非敏感标记，保存后在同一身份更新与刷新签名后检查它是否仍在。标记保存在 Application Support，不属于阅读记录。';

  @override
  String get diagnosticsMarker => '保留测试标记';

  @override
  String get diagnosticsSaveMarker => '保存标记';

  @override
  String get diagnosticsMarkerSaved => '标记已保存';

  @override
  String get diagnosticsSqliteTitle => 'SQLite 存储自检';

  @override
  String get diagnosticsSqliteHelp =>
      '在后台隔离区使用 Application Support 临时数据库，完成后删除。自检后请开始并停止采集，或重新导出已有记录，以保存最新结果。';

  @override
  String get diagnosticsSqliteRun => '运行 SQLite 自检';

  @override
  String get diagnosticsSqliteRunning => 'SQLite 自检运行中…';

  @override
  String get diagnosticsSqlitePass => '通过';

  @override
  String get diagnosticsSqliteFail => '失败';

  @override
  String get diagnosticsSqliteNotRun => '未运行';

  @override
  String diagnosticsSqliteOutcome(String status) {
    return 'SQLite 自检结果：$status';
  }

  @override
  String diagnosticsSqliteCheckedAt(String time) {
    return '自检时间（UTC）：$time';
  }

  @override
  String get diagnosticsSqliteOpen => '新建并打开数据库';

  @override
  String get diagnosticsSqliteCommit => '提交事务';

  @override
  String get diagnosticsSqliteReopen => '关闭、重开并读取提交内容';

  @override
  String get diagnosticsSqliteRollback => '失败事务回滚数据、结构与版本';

  @override
  String get diagnosticsSqliteFutureSchema => '拒绝未来版本且文件未变';

  @override
  String get diagnosticsSqliteCleanup => '删除临时数据库';

  @override
  String diagnosticsSqliteStep(String step, String status) {
    return '$step：$status';
  }

  @override
  String diagnosticsSqliteRuntime(
    String packageVersion,
    String libraryVersion,
    String journalMode,
    String synchronous,
    int elapsedUs,
  ) {
    return 'sqlite3 包：$packageVersion；SQLite 库：$libraryVersion；journal：$journalMode；synchronous：$synchronous；耗时：$elapsedUs 微秒';
  }

  @override
  String diagnosticsSqliteSource(String sourceId) {
    return 'SQLite 源码标识：$sourceId';
  }

  @override
  String diagnosticsSqliteOptions(String options) {
    return 'SQLite 编译选项：$options';
  }

  @override
  String get commonCancel => '取消';

  @override
  String get serverSetupTitle => '连接书库';

  @override
  String get serverChangeTitle => '更换服务器';

  @override
  String get serverSetupHelp => '输入书库服务器的完整地址。更换连接失败时，仍会保留原来的书库。';

  @override
  String get serverUrlLabel => '服务器地址';

  @override
  String serverCurrent(String address) {
    return '当前服务器：$address';
  }

  @override
  String get serverConnect => '连接';

  @override
  String get serverConnecting => '正在连接…';

  @override
  String get serverSaving => '正在保存连接…';

  @override
  String get serverRestoring => '正在恢复连接…';

  @override
  String get serverRestoreFailed => '无法恢复已保存的连接。请重试；如果刚更新过应用，请确认正在使用兼容的版本。';

  @override
  String get serverUrlScheme => '地址必须以 http:// 或 https:// 开头。';

  @override
  String get serverUrlHost => '请填写有效的服务器名称或网络地址。';

  @override
  String get serverUrlCredentials => '地址中不能包含用户名或密码。';

  @override
  String get serverUrlQuery => '请移除地址中问号及其后的内容。';

  @override
  String get serverUrlFragment => '请移除地址中井号及其后的内容。';

  @override
  String get serverUrlEscape => '地址中的百分号编码不完整，请检查后重试。';

  @override
  String get serverUrlBackslash => '请将地址中的反斜杠改为正斜杠。';

  @override
  String get serverUrlPort => '端口号应为 1 到 65535 的整数。';

  @override
  String get serverUrlZone => '请使用不带网卡标识的 IPv6 地址，或改用服务器名称。';

  @override
  String get serverUrlInvalid => '地址格式不正确，请检查后重试。';

  @override
  String get serverConnectionFailed => '连接超时或网络不可用。请确认服务器已开启，并检查网络后重试。';

  @override
  String get serverTlsFailed => '无法建立安全连接。请检查服务器证书和设备时间后重试。';

  @override
  String get serverAccessDenied => '服务器拒绝访问。请检查服务器的访问设置后重试。';

  @override
  String get serverWrongService => '此地址不是受支持的书库服务，请检查服务器地址。';

  @override
  String get serverLibraryUnconfigured => '服务器尚未设置书库。请先完成服务器设置，再重试。';

  @override
  String get serverLibraryUnavailable => '服务器暂时无法读取书库。请检查服务器状态后重试。';

  @override
  String get serverUnsupportedVersion => '此书库版本暂不受支持。请检查应用和服务器版本是否兼容。';

  @override
  String get serverUnexpectedResponse =>
      '服务器返回了无法识别的内容，可能是登录页或代理页面。请检查访问设置和服务器地址后重试。';

  @override
  String get serverFinalAddress => '此地址发生了无法继续的跳转。请填写跳转后书库的完整地址，再重新连接。';

  @override
  String get serverResponseFailed => '服务器暂时无法完成请求。请检查服务器状态后重试。';

  @override
  String get serverSaveFailed => '无法保存新的连接。原有连接已保留，请稍后重试。';

  @override
  String get serverLocalNetworkHelp =>
      '连接家中或局域网内的服务器时，请确认设备与服务器处于可互通的网络。如果仍无法连接，可在 iPhone 的“设置”→“隐私与安全性”→“本地网络”中允许 Shiori 访问，然后返回重试。网络错误也可能由服务器未开启或地址不正确引起。';

  @override
  String get libraryTitle => '书库';

  @override
  String get libraryBookTitle => '书籍信息';

  @override
  String get libraryRefresh => '刷新书库';

  @override
  String get libraryRefreshing => '正在刷新书库…';

  @override
  String get libraryLoading => '正在读取书库…';

  @override
  String get libraryStale => '正在显示已保存的书库，内容可能不是最新的；离线时仍可浏览。';

  @override
  String get libraryLoadFailed => '暂时无法读取书库，请重试。';

  @override
  String get libraryEmpty => '书库里还没有书籍。';

  @override
  String get libraryFolderEmpty => '此文件夹里还没有书籍。';

  @override
  String get libraryFolderMissing => '找不到此文件夹，请刷新书库后重试。';

  @override
  String get libraryBookMissing => '找不到此书籍，请刷新书库后重试。';

  @override
  String get libraryUnknownAuthor => '作者未知';

  @override
  String get libraryPreparationTitle => '准备书籍';

  @override
  String get libraryPreparationHelp => '下载并检查此书，为之后阅读做好准备。离开此页面后，准备仍会继续。';

  @override
  String get libraryPreparationStart => '准备此书';

  @override
  String get libraryPreparationWorking => '正在准备书籍…';

  @override
  String libraryPreparationProgress(int percent) {
    return '已下载 $percent%';
  }

  @override
  String get libraryPreparationCheckingHelp => '下载完成后还需检查内容，请等待准备完成。';

  @override
  String get libraryPreparationReady => '书籍已下载并检查完成。阅读器可用后即可打开。';

  @override
  String get libraryPreparationRefresh => '重新准备';

  @override
  String get libraryPreparationRefreshHelp => '重新获取并检查服务器上的此书。';

  @override
  String get libraryPreparationUnavailable =>
      '服务器上暂时找不到此书，可能已被移除。请刷新书库，确认书籍仍在后重试。';

  @override
  String get libraryPreparationTooLarge =>
      '此书过大，暂时无法准备。可换一本较小的书；更换此书的较小版本后可重试。';

  @override
  String get libraryPreparationBusy =>
      '下载空间暂时不可用，或另一本书正在准备。请稍后重试；若空间不足，可先释放设备储存空间。';

  @override
  String get libraryPreparationInvalid =>
      '此书内容不完整或结构有误，无法完成检查。请在服务器上更换完整的 EPUB 后重试。';

  @override
  String get libraryPreparationUnsupported =>
      '暂时无法检查此书的内容结构。请尝试更新应用，或在服务器上更换 EPUB 后重试。';

  @override
  String get libraryPreparationStorage => '无法保存此书。请检查设备的可用储存空间，然后重试。';

  @override
  String get libraryPreparationInterrupted => '书籍准备意外中断，请重试。';

  @override
  String libraryBookCount(int count) {
    return '$count 本书';
  }

  @override
  String libraryCoverLabel(String title) {
    return '《$title》的封面';
  }

  @override
  String get appTitle => 'Shiori';

  @override
  String get homeTitle => '首页';

  @override
  String get homeWelcome => '欢迎使用 Shiori';

  @override
  String get commonRetry => '重试';

  @override
  String get errorNetwork => '网络连接失败，请检查网络后重试';

  @override
  String get errorUnauthorized => '登录已失效，请重新登录';

  @override
  String get errorServer => '服务器出错了，请稍后再试';

  @override
  String get errorUnexpected => '发生未知错误';
}
