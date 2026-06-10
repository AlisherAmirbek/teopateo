import Foundation
import Sentry

/// Central wrapper around the Sentry SDK.
///
/// Scope is deliberately limited to crash + error reporting — no performance
/// tracing and no profiling — to keep collection lean and consistent with the
/// app's privacy posture. All configuration lives here so there is a single
/// place to audit what leaves the device.
enum Observability {
    /// Sentry client key (DSN). This is public by design: it only authorizes
    /// *sending* events to this project and is safe to ship in the app binary.
    private static let dsn = "https://8671a101f9171d5aa896c4ad4eb18161@o4511542057041920.ingest.us.sentry.io/4511542061957120"

    /// Initialize crash/error reporting. Call once, as early as possible.
    static func start() {
        let processInfo = ProcessInfo.processInfo

        // Never report from automated UI test runs.
        guard !processInfo.arguments.contains("-teopateo-ui-testing") else { return }

        #if DEBUG
        // Stay silent during everyday development so the production project is
        // not polluted with simulator noise. Opt in for local verification by
        // setting SENTRY_DEBUG_ENABLED=1 in the run scheme's environment.
        guard processInfo.environment["SENTRY_DEBUG_ENABLED"] == "1" else { return }
        let environmentName = "debug"
        #else
        let environmentName = "production"
        #endif

        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = environmentName

            // Crashes + handled errors only — no performance tracing, no profiling.
            options.tracesSampleRate = 0.0

            // Privacy: do not attach IP addresses or other default PII. Events
            // carry only device/OS metadata and stack traces.
            options.sendDefaultPii = false

            #if DEBUG
            options.debug = true
            #endif
        }
    }

    /// Report a handled (non-fatal) error, tagged with a coarse `category` for
    /// filtering in Sentry. No user content is attached.
    static func record(_ error: Error, category: String) {
        SentrySDK.capture(error: error) { scope in
            scope.setTag(value: category, key: "category")
        }
    }
}
