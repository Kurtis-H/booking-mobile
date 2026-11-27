/// A deliberate, switchable bug, used to prove that test suites can fail.
///
/// framework-showdown (github.com/Kurtis-H/framework-showdown) builds this app
/// with `--dart-define=PLANTED_BUG=total` and checks that every framework's
/// suite catches it. It's empty, and does nothing, in every normal build.
///
/// Bugs:
///   total - the order total counts only the first selected seat.
const plantedBug = String.fromEnvironment('PLANTED_BUG');
