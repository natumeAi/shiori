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
