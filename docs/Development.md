# Development and widget troubleshooting

[Documentation](README.md)

These are developer notes, not prerequisites for using an installed app.
Open `NR Status.xcodeproj` in Xcode. The current deployment target is macOS 15.

## Direct distribution and AI commands

The main app disables App Sandbox in both Debug and Release for direct
distribution. AI Assist launches a user-configured CLI directly with
Foundation `Process`; no user-script helper is needed. The widget extension
remains sandboxed, and App Group and Keychain entitlements remain in place.

A future Mac App Store release would need to restore the main app's sandbox
and redesign arbitrary external CLI execution, for example around a
user-installed `NSUserUnixTask` script or a supported service integration.
Do not simply enable the sandbox and expect installed AI tools to retain
access to their configuration and credentials.

## Widget signing and registration

The Workbook extension has its own bundle ID and development provisioning
profile. Both app and extension enable App Groups registration for automatic
provisioning and need profiles authorizing `group.net.baurhome.NR-Status`.
This registered group shares Keychain items even when targets have different
App ID prefixes; workbook storage remains in the original macOS App Group.

The configuration intent belongs only to the widget extension; do not compile
it into the app target too. Verify widget configuration with a normal signed
app build: test-host and unsigned builds do not reproduce normal App Group
and Keychain authorization.

Keep only the current app build registered with macOS. Old copies with the
same bundle ID can prevent WidgetKit from resolving the new configuration
intent, leaving a placeholder without **Edit Widget**. Unregister specific
obsolete app paths with Launch Services rather than deleting system widget
caches. Unregistering the extension alone does not remove its containing
app's intent registration.

The old chart-specific widgets were replaced, not migrated. Remove those
desktop widgets and add **Workbook** widgets.

## Saved-key migration

Legacy settings migrate to a profile named `Default`. Keys are copied from the
original access group when first used; the old copy is kept until the profile
is deleted.

Keychain entries use `NR Status named API key (<key name>)`; the account field
also uses the configured name. Renaming updates both, with the UUID stored
separately. Older UUID-based labels/account fields update on the next save.

## Repeatable visual checks

Use [`ChartSamples.nrmd`](examples/ChartSamples.nrmd) for fixed, offline chart
data. See [the capture guide](Screenshots.md) for a focused screenshot checklist.
