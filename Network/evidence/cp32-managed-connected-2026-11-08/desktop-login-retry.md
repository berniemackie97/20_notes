# Desktop login retry stalls after a refused attempt

Verified on OCC `89ca6e8a2fc2e878889169cbd201065deb95835f` against OCS `e69aaf8d0db18e50952ce4ae587cdf20a4a031d7`, macOS arm64, verified retail content and isolated MySQL. The owner reported that pressing Enter left the desktop at login. The background continued rendering and Escape opened the quit dialog. The same disposable valid account reached the creation screen after restarting the test app. The initial desktop observation does not prove the prior attempt's exact result.

## Deterministic reproduction

A temporary external test used the real OCC login screen and ClientLogin, original-content loading timeline, and live OCS AccountServer. An unknown synthetic account first reached `AccountRefused`. The test dismissed the refusal dialog, entered a valid disposable account/password and pressed Enter. It then advanced the same update, feedback and loading calls used by ClientSession, in the same order.

| Step | AwaitingLoginCommand | Loading frame | Attempt status |
| --- | --- | --- | --- |
| Immediately after retry | true | 2 | AccountRefused (prior attempt) |
| After first 34 ms presentation update | true | 1 | AccountRefused |
| After 30 more update/presentation cycles | true | 1 | AccountRefused |

The assertion-based reproduction passed. `ClientLogin.OnLoginRequested` starts the loading sequence and sets `AwaitingLoginCommand`. `LoginLoadingScreen.Update` sees the prior terminal status, resets the new sequence to frame 1, and leaves the command pending. `ClientLogin.Update` only consumes the pending command at frame 17. The old refusal cannot be replaced by a new attempt until that dispatch occurs. This is a state-transition stall that can leave the renderer running.

Required regression: refuse an attempt, dismiss the dialog, retry with a valid account after the existing retry guard and verify exactly one new account exchange at frame 17, visible transition to creation/world, and no stuck pending state. Exercise other terminal statuses that share the reset branch, plus focus loss and Escape before dispatch. Keep the existing credential erasure, guard, and transport ownership.
