/// App lock "Lock after" choices (backlog #24): how long Megrim may sit in the background before it
/// asks for the phone's unlock again. A cold start always locks.
const Duration kAppLockDefaultTimeout = Duration(minutes: 1);

const List<Duration> kAppLockTimeoutChoices = [
  Duration.zero,
  Duration(minutes: 1),
  Duration(minutes: 5),
  Duration(minutes: 15),
];

String appLockTimeoutLabel(Duration d) {
  if (d == Duration.zero) return 'Immediately';
  final m = d.inMinutes;
  return m == 1 ? 'After 1 minute' : 'After $m minutes';
}
