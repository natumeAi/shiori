import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('zh')];

  /// No description provided for @diagnosticsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设备诊断探针'**
  String get diagnosticsTitle;

  /// No description provided for @probeSynthetic.
  ///
  /// In zh, this message translates to:
  /// **'S1 合成动画采集'**
  String get probeSynthetic;

  /// No description provided for @readerProbeTitle.
  ///
  /// In zh, this message translates to:
  /// **'阅读器可行性探针'**
  String get readerProbeTitle;

  /// No description provided for @readerProbeHelp.
  ///
  /// In zh, this message translates to:
  /// **'从内置夹具或 Documents 中选择 EPUB。用户书籍仅以 SHA-256 标识。引擎提交不等于物理呈现；原生呈现数据尚未验证。'**
  String get readerProbeHelp;

  /// No description provided for @readerProbeControls.
  ///
  /// In zh, this message translates to:
  /// **'探针控制'**
  String get readerProbeControls;

  /// No description provided for @readerBooks.
  ///
  /// In zh, this message translates to:
  /// **'选择书籍 / 刷新列表'**
  String get readerBooks;

  /// No description provided for @readerFixture.
  ///
  /// In zh, this message translates to:
  /// **'夹具：{id}'**
  String readerFixture(String id);

  /// No description provided for @readerUserBook.
  ///
  /// In zh, this message translates to:
  /// **'用户书籍 SHA-256：{digest}'**
  String readerUserBook(String digest);

  /// No description provided for @readerEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有可用书籍，请将 EPUB 放入 Documents 后刷新。'**
  String get readerEmpty;

  /// No description provided for @readerUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'此书包含固定版式、竖排或从右至左布局，探针无法打开。可选择其他书籍。'**
  String get readerUnsupported;

  /// No description provided for @readerFailure.
  ///
  /// In zh, this message translates to:
  /// **'无法打开、准备或证明阅读位置，请重试或选择其他书籍。'**
  String get readerFailure;

  /// No description provided for @readerFont.
  ///
  /// In zh, this message translates to:
  /// **'字体'**
  String get readerFont;

  /// No description provided for @readerFontName.
  ///
  /// In zh, this message translates to:
  /// **'{id, select, system{默认} pingfang{苹方} yahei{微软雅黑} sans{黑体} serif{宋体} kai{楷体} other{默认}}'**
  String readerFontName(String id);

  /// No description provided for @readerSize.
  ///
  /// In zh, this message translates to:
  /// **'字号'**
  String get readerSize;

  /// No description provided for @readerLineHeight.
  ///
  /// In zh, this message translates to:
  /// **'行高'**
  String get readerLineHeight;

  /// No description provided for @readerLetterSpacing.
  ///
  /// In zh, this message translates to:
  /// **'字距（em）'**
  String get readerLetterSpacing;

  /// No description provided for @readerHorizontalMargin.
  ///
  /// In zh, this message translates to:
  /// **'水平附加边距'**
  String get readerHorizontalMargin;

  /// No description provided for @readerVerticalMargin.
  ///
  /// In zh, this message translates to:
  /// **'垂直附加边距'**
  String get readerVerticalMargin;

  /// No description provided for @readerTheme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get readerTheme;

  /// No description provided for @readerThemeName.
  ///
  /// In zh, this message translates to:
  /// **'{id, select, light{明亮} sepia{柔和} green{护眼} dark{深色} other{主题 {id}}}'**
  String readerThemeName(String id);

  /// No description provided for @readerSettingValue.
  ///
  /// In zh, this message translates to:
  /// **'{label}：{value}'**
  String readerSettingValue(String label, String value);

  /// No description provided for @readerReducedMotion.
  ///
  /// In zh, this message translates to:
  /// **'减少动态效果'**
  String get readerReducedMotion;

  /// No description provided for @readerJump.
  ///
  /// In zh, this message translates to:
  /// **'跳转章节'**
  String get readerJump;

  /// No description provided for @readerSection.
  ///
  /// In zh, this message translates to:
  /// **'第 {number} 节'**
  String readerSection(int number);

  /// No description provided for @readerScenario.
  ///
  /// In zh, this message translates to:
  /// **'场景'**
  String get readerScenario;

  /// No description provided for @readerScenarioName.
  ///
  /// In zh, this message translates to:
  /// **'{id, select, R01{R01 前后各 40 次轻点} R02{R02 拖动、快滑、反向和边界回弹} R03{R03 按住手指等待冷邻页} R04{R04 队列溢出和跳转} R05{R05 冷热双向跨章} R06{R06 十万字长段落} R07{R07 图文和 SVG} R08{R08 字号行高重排和锚点恢复} R09{R09 运动及准备时模拟后台恢复} R10{R10 百次交替翻页和跳转资源采样} R11{R11 用户书籍手动阅读至少 50 次} other{未知场景}}'**
  String readerScenarioName(String id);

  /// No description provided for @readerRepeat.
  ///
  /// In zh, this message translates to:
  /// **'重复次数（默认 3）'**
  String get readerRepeat;

  /// No description provided for @readerManual.
  ///
  /// In zh, this message translates to:
  /// **'手动触摸采集（R11 必须使用用户书籍）'**
  String get readerManual;

  /// No description provided for @readerStart.
  ///
  /// In zh, this message translates to:
  /// **'开始阅读器采集'**
  String get readerStart;

  /// No description provided for @readerRunning.
  ///
  /// In zh, this message translates to:
  /// **'正在采集；脚本触摸为注入输入，后台切换为控制器模拟。'**
  String get readerRunning;

  /// No description provided for @readerPosition.
  ///
  /// In zh, this message translates to:
  /// **'第 {section} 节 · 第 {page}/{total} 页'**
  String readerPosition(int section, int page, int total);

  /// No description provided for @readerManualMinimum.
  ///
  /// In zh, this message translates to:
  /// **'R11 每本书至少完成 50 次已接受翻页；提前停止的记录保留为不完整证据。'**
  String get readerManualMinimum;

  /// No description provided for @readerNativeMode.
  ///
  /// In zh, this message translates to:
  /// **'原生呈现证据（仅诊断）'**
  String get readerNativeMode;

  /// No description provided for @readerNativeModeName.
  ///
  /// In zh, this message translates to:
  /// **'{mode, select, inventory{系统信息} a1{A1 图层提交（无辅助显示链接）} a2{A2 图层提交及辅助显示链接} b{B 非默认路径的 drawable 呈现} other{未知}}'**
  String readerNativeModeName(String mode);

  /// No description provided for @diagnosticsBuild.
  ///
  /// In zh, this message translates to:
  /// **'构建 {buildId} · 版本号 {number}'**
  String diagnosticsBuild(String buildId, String number);

  /// No description provided for @diagnosticsEvidence.
  ///
  /// In zh, this message translates to:
  /// **'本探针只记录合成动画的引擎耗时与调度节奏；物理显示帧率及 EPUB 阅读性能尚未验证。请先声明设备设置。'**
  String get diagnosticsEvidence;

  /// No description provided for @diagnosticsDeviceModel.
  ///
  /// In zh, this message translates to:
  /// **'设备型号（手动填写，可留空）'**
  String get diagnosticsDeviceModel;

  /// No description provided for @diagnosticsLowPower.
  ///
  /// In zh, this message translates to:
  /// **'低电量模式（用户声明）'**
  String get diagnosticsLowPower;

  /// No description provided for @diagnosticsLimitRate.
  ///
  /// In zh, this message translates to:
  /// **'辅助功能 → 动态效果 → 限制帧速率（用户声明）'**
  String get diagnosticsLimitRate;

  /// No description provided for @diagnosticsCharging.
  ///
  /// In zh, this message translates to:
  /// **'正在充电（用户声明）'**
  String get diagnosticsCharging;

  /// No description provided for @diagnosticsWarm.
  ///
  /// In zh, this message translates to:
  /// **'手机感觉发热（用户声明）'**
  String get diagnosticsWarm;

  /// No description provided for @diagnosticsOn.
  ///
  /// In zh, this message translates to:
  /// **'开 / 是'**
  String get diagnosticsOn;

  /// No description provided for @diagnosticsOff.
  ///
  /// In zh, this message translates to:
  /// **'关 / 否'**
  String get diagnosticsOff;

  /// No description provided for @diagnosticsUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get diagnosticsUnknown;

  /// No description provided for @diagnosticsStart.
  ///
  /// In zh, this message translates to:
  /// **'开始采集（最多 15 秒）'**
  String get diagnosticsStart;

  /// No description provided for @diagnosticsStop.
  ///
  /// In zh, this message translates to:
  /// **'停止采集'**
  String get diagnosticsStop;

  /// No description provided for @diagnosticsRecording.
  ///
  /// In zh, this message translates to:
  /// **'正在采集连续运动…'**
  String get diagnosticsRecording;

  /// No description provided for @diagnosticsDraining.
  ///
  /// In zh, this message translates to:
  /// **'正在等待延迟的引擎报告…'**
  String get diagnosticsDraining;

  /// No description provided for @diagnosticsStorageError.
  ///
  /// In zh, this message translates to:
  /// **'无法读取或保存本地诊断，请重试。'**
  String get diagnosticsStorageError;

  /// No description provided for @diagnosticsExporting.
  ///
  /// In zh, this message translates to:
  /// **'正在写入诊断文件…'**
  String get diagnosticsExporting;

  /// No description provided for @diagnosticsResult.
  ///
  /// In zh, this message translates to:
  /// **'运行 {runId}：{frames} 个引擎样本，{motion} 个运动事件'**
  String diagnosticsResult(String runId, int frames, int motion);

  /// No description provided for @diagnosticsPartial.
  ///
  /// In zh, this message translates to:
  /// **'部分证据：无法保证最后一批引擎报告已全部到达。未知与溢出状态保留在文件中。'**
  String get diagnosticsPartial;

  /// No description provided for @diagnosticsCadence.
  ///
  /// In zh, this message translates to:
  /// **'观测到的引擎节奏：{pattern}'**
  String diagnosticsCadence(String pattern);

  /// No description provided for @diagnosticsCadence120.
  ///
  /// In zh, this message translates to:
  /// **'接近 120 Hz（并非物理呈现证明）'**
  String get diagnosticsCadence120;

  /// No description provided for @diagnosticsCadence60.
  ///
  /// In zh, this message translates to:
  /// **'低阶段耗时、接近 60 Hz，与系统限速相符'**
  String get diagnosticsCadence60;

  /// No description provided for @diagnosticsCadenceMixed.
  ///
  /// In zh, this message translates to:
  /// **'混合节奏，存在超预算阶段'**
  String get diagnosticsCadenceMixed;

  /// No description provided for @diagnosticsCadenceUnknown.
  ///
  /// In zh, this message translates to:
  /// **'样本不足或结果不确定'**
  String get diagnosticsCadenceUnknown;

  /// No description provided for @diagnosticsExported.
  ///
  /// In zh, this message translates to:
  /// **'已写入：{path}'**
  String diagnosticsExported(String path);

  /// No description provided for @diagnosticsExport.
  ///
  /// In zh, this message translates to:
  /// **'写入 / 重试导出文件'**
  String get diagnosticsExport;

  /// No description provided for @diagnosticsCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制简短摘要'**
  String get diagnosticsCopy;

  /// No description provided for @diagnosticsCopied.
  ///
  /// In zh, this message translates to:
  /// **'摘要已复制；原始证据请从文件取回'**
  String get diagnosticsCopied;

  /// No description provided for @diagnosticsMotion.
  ///
  /// In zh, this message translates to:
  /// **'连续变换的合成诊断画面'**
  String get diagnosticsMotion;

  /// No description provided for @diagnosticsMarkerHelp.
  ///
  /// In zh, this message translates to:
  /// **'填写非敏感标记，保存后在同一身份更新与刷新签名后检查它是否仍在。标记保存在 Application Support，不属于阅读记录。'**
  String get diagnosticsMarkerHelp;

  /// No description provided for @diagnosticsMarker.
  ///
  /// In zh, this message translates to:
  /// **'保留测试标记'**
  String get diagnosticsMarker;

  /// No description provided for @diagnosticsSaveMarker.
  ///
  /// In zh, this message translates to:
  /// **'保存标记'**
  String get diagnosticsSaveMarker;

  /// No description provided for @diagnosticsMarkerSaved.
  ///
  /// In zh, this message translates to:
  /// **'标记已保存'**
  String get diagnosticsMarkerSaved;

  /// No description provided for @diagnosticsSqliteTitle.
  ///
  /// In zh, this message translates to:
  /// **'SQLite 存储自检'**
  String get diagnosticsSqliteTitle;

  /// No description provided for @diagnosticsSqliteHelp.
  ///
  /// In zh, this message translates to:
  /// **'在后台隔离区使用 Application Support 临时数据库，完成后删除。自检后请开始并停止采集，或重新导出已有记录，以保存最新结果。'**
  String get diagnosticsSqliteHelp;

  /// No description provided for @diagnosticsSqliteRun.
  ///
  /// In zh, this message translates to:
  /// **'运行 SQLite 自检'**
  String get diagnosticsSqliteRun;

  /// No description provided for @diagnosticsSqliteRunning.
  ///
  /// In zh, this message translates to:
  /// **'SQLite 自检运行中…'**
  String get diagnosticsSqliteRunning;

  /// No description provided for @diagnosticsSqlitePass.
  ///
  /// In zh, this message translates to:
  /// **'通过'**
  String get diagnosticsSqlitePass;

  /// No description provided for @diagnosticsSqliteFail.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get diagnosticsSqliteFail;

  /// No description provided for @diagnosticsSqliteNotRun.
  ///
  /// In zh, this message translates to:
  /// **'未运行'**
  String get diagnosticsSqliteNotRun;

  /// No description provided for @diagnosticsSqliteOutcome.
  ///
  /// In zh, this message translates to:
  /// **'SQLite 自检结果：{status}'**
  String diagnosticsSqliteOutcome(String status);

  /// No description provided for @diagnosticsSqliteCheckedAt.
  ///
  /// In zh, this message translates to:
  /// **'自检时间（UTC）：{time}'**
  String diagnosticsSqliteCheckedAt(String time);

  /// No description provided for @diagnosticsSqliteOpen.
  ///
  /// In zh, this message translates to:
  /// **'新建并打开数据库'**
  String get diagnosticsSqliteOpen;

  /// No description provided for @diagnosticsSqliteCommit.
  ///
  /// In zh, this message translates to:
  /// **'提交事务'**
  String get diagnosticsSqliteCommit;

  /// No description provided for @diagnosticsSqliteReopen.
  ///
  /// In zh, this message translates to:
  /// **'关闭、重开并读取提交内容'**
  String get diagnosticsSqliteReopen;

  /// No description provided for @diagnosticsSqliteRollback.
  ///
  /// In zh, this message translates to:
  /// **'失败事务回滚数据、结构与版本'**
  String get diagnosticsSqliteRollback;

  /// No description provided for @diagnosticsSqliteFutureSchema.
  ///
  /// In zh, this message translates to:
  /// **'拒绝未来版本且文件未变'**
  String get diagnosticsSqliteFutureSchema;

  /// No description provided for @diagnosticsSqliteCleanup.
  ///
  /// In zh, this message translates to:
  /// **'删除临时数据库'**
  String get diagnosticsSqliteCleanup;

  /// No description provided for @diagnosticsSqliteStep.
  ///
  /// In zh, this message translates to:
  /// **'{step}：{status}'**
  String diagnosticsSqliteStep(String step, String status);

  /// No description provided for @diagnosticsSqliteRuntime.
  ///
  /// In zh, this message translates to:
  /// **'sqlite3 包：{packageVersion}；SQLite 库：{libraryVersion}；journal：{journalMode}；synchronous：{synchronous}；耗时：{elapsedUs} 微秒'**
  String diagnosticsSqliteRuntime(
    String packageVersion,
    String libraryVersion,
    String journalMode,
    String synchronous,
    int elapsedUs,
  );

  /// No description provided for @diagnosticsSqliteSource.
  ///
  /// In zh, this message translates to:
  /// **'SQLite 源码标识：{sourceId}'**
  String diagnosticsSqliteSource(String sourceId);

  /// No description provided for @diagnosticsSqliteOptions.
  ///
  /// In zh, this message translates to:
  /// **'SQLite 编译选项：{options}'**
  String diagnosticsSqliteOptions(String options);

  /// Application name shown by the OS task switcher and window title.
  ///
  /// In zh, this message translates to:
  /// **'Shiori'**
  String get appTitle;

  /// App bar title of the home screen.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get homeTitle;

  /// Welcome text shown in the body of the placeholder home screen.
  ///
  /// In zh, this message translates to:
  /// **'欢迎使用 Shiori'**
  String get homeWelcome;

  /// Button label for retrying a failed action or load.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get commonRetry;

  /// Shown when a request fails because of no connection or a timeout.
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败，请检查网络后重试'**
  String get errorNetwork;

  /// Shown when the server rejects the request as unauthorized (401/403).
  ///
  /// In zh, this message translates to:
  /// **'登录已失效，请重新登录'**
  String get errorUnauthorized;

  /// Shown when the server returns an error or an unexpected response.
  ///
  /// In zh, this message translates to:
  /// **'服务器出错了，请稍后再试'**
  String get errorServer;

  /// Fallback message for errors that have no specific mapping.
  ///
  /// In zh, this message translates to:
  /// **'发生未知错误'**
  String get errorUnexpected;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
