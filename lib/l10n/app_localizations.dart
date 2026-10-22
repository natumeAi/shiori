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
