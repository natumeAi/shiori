import 'package:freezed_annotation/freezed_annotation.dart';
part 'probe_declarations.freezed.dart';
part 'probe_declarations.g.dart';

enum DeclaredSetting { on, off, unknown }

@freezed
abstract class ProbeDeclarations with _$ProbeDeclarations {
  const factory ProbeDeclarations({
    @Default('') String deviceModel,
    @Default(DeclaredSetting.unknown) DeclaredSetting lowPowerMode,
    @Default(DeclaredSetting.unknown) DeclaredSetting limitFrameRate,
    @Default(DeclaredSetting.unknown) DeclaredSetting charging,
    @Default(DeclaredSetting.unknown) DeclaredSetting warm,
    @Default('user_provided') String source,
  }) = _ProbeDeclarations;
  factory ProbeDeclarations.fromJson(Map<String, Object?> json) =>
      _$ProbeDeclarationsFromJson(json);
}
