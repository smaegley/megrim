import '../l10n/l10n.dart';

/// App lock "Lock after" choices (backlog #24): how long Megrim may sit in the background before it
/// asks for the phone's unlock again. A cold start always locks.
const Duration kAppLockDefaultTimeout = Duration(minutes: 1);

const List<Duration> kAppLockTimeoutChoices = [
  Duration.zero,
  Duration(minutes: 1),
  Duration(minutes: 5),
  Duration(minutes: 15),
];

/// "Immediately" / "After 5 minutes". English unless [l] is given.
String appLockTimeoutLabel(Duration d, [AppLocalizations? l]) =>
    (l ?? englishL10n).appLockAfterMinutes(d.inMinutes);
