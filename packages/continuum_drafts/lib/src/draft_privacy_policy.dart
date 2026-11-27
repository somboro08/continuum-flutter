import 'draft_field.dart';

/// Explicit allow-list for draft field persistence.
///
/// By default only ordinary fields are eligible. Secret, one-time-code and
/// payment fields are always excluded, even if accidentally allow-listed.
class DraftPrivacyPolicy {
  DraftPrivacyPolicy({
    Set<DraftFieldSensitivity> allowedSensitivities = const <DraftFieldSensitivity>{
      DraftFieldSensitivity.ordinary,
    },
  }) : allowedSensitivities = Set<DraftFieldSensitivity>.unmodifiable(
          allowedSensitivities,
        );

  final Set<DraftFieldSensitivity> allowedSensitivities;

  bool allows(DraftFieldDefinition field) {
    if (!field.persist) return false;
    switch (field.sensitivity) {
      case DraftFieldSensitivity.secret:
      case DraftFieldSensitivity.oneTimeCode:
      case DraftFieldSensitivity.payment:
        return false;
      case DraftFieldSensitivity.ordinary:
      case DraftFieldSensitivity.personal:
        return allowedSensitivities.contains(field.sensitivity);
    }
  }
}
