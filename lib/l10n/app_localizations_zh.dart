// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

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
