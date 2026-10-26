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
