# Archie

A native **macOS** app that pairs a local terminal (your login shell) with an AI chat sidebar. Each turn sends chat history plus a snapshot of the terminal buffer so the model can suggest commands and guidance in context.

## Features

- **Three-column layout:** session list, terminal (**SwiftTerm** / `LocalProcessTerminalView`), and chat with assistant replies and optional one-line shell commands you can send to the terminal.
- **Multi-provider AI:** OpenAI, Anthropic Claude, and DeepSeek — switch provider and model under **Archie → Settings…**.
- **SwiftData:** sessions and messages persist locally; first launch runs lightweight bootstrap/migration.
- **Themes:** Standard (system-aligned colors) and Matrix (dark neon); switch under **Archie → Settings…**.
- **String catalog:** `Sources/Archie/Resources/Localizable.xcstrings` — base language English; keys such as `session.sidebar.title`; add locales via Xcode or by editing the catalog.
- **Window sizing:** Minimum width follows column minimums plus chrome; `windowResizability(.contentMinSize)` keeps the split layout from breaking when the window is too narrow.

## Requirements

- macOS **14** or later
- **Swift 5.9+** (`swift-tools-version` in `Package.swift`)
- An API key from at least one supported provider (OpenAI, Anthropic, or DeepSeek)

## AI providers & models

Configure the active provider under **Archie → Settings…**. Defaults when unset:

| Provider | Default model | Available models |
| -------- | ------------- | ---------------- |
| OpenAI | `gpt-5.4-mini` | `gpt-5.4-mini`, `gpt-5.4`, `gpt-5.5` |
| Claude | `claude-sonnet-4-20250514` | Sonnet, Opus, Haiku |
| DeepSeek | `deepseek-chat` | `deepseek-chat`, `deepseek-reasoner` |

## API keys

Keys are **never hardcoded**. For the selected provider, resolution order is:

1. **Keychain** — save from **Archie → Settings…** (“Save to Keychain”)
2. **Environment variable** — used when Keychain has no value (handy for scripts and launching from Terminal)

| Provider | Env variable | Keychain service |
| -------- | ------------ | ---------------- |
| OpenAI | `OPENAI_API_KEY` | `com.typekit.archie.openai` |
| Claude | `ANTHROPIC_API_KEY` | `com.typekit.archie.claude` |
| DeepSeek | `DEEPSEEK_API_KEY` | `com.typekit.archie.deepseek` |

After changing a key or provider, the app refreshes the client via `invalidateClient()` (the Settings buttons already trigger this).

Example — launch with OpenAI from Terminal:

```bash
export OPENAI_API_KEY="sk-..."
swift run Archie
```

## Build & run

### Swift Package Manager

From the repo root (next to `Package.swift`):

```bash
swift build
swift run Archie
```

### Xcode

Open `Archie.xcodeproj`, select the **Archie** scheme, build for **My Mac**.

Set your **Development Team** in Signing & Capabilities if Xcode prompts for it. Release builds for the Mac App Store require your own provisioning profile locally — signing files are not committed to the repo.

**SwiftTerm** is fetched through Swift Package Manager (see `Package.swift` and the Xcode project package reference).

## Source layout

Code root: `Sources/Archie/`.

| Area | Role |
| ---- | ---- |
| `App/` | Entry point, `ContentView`, column split (`NavigationSplitView`, `HSplitView`). |
| `Terminal/` | Embedded terminal and process bridge (`TerminalHostView`, `TerminalSessionBridge`). |
| `Chat/` | Domain (`ChatAPI`, models), infrastructure (OpenAI / Claude / DeepSeek APIs, persistence), `ChatRouter`, send pipeline, sidebar + chat UI. |
| `Settings/` | Settings UI, provider selection, and Keychain wrappers for API keys. |
| `Theme/` | Palettes and theme selection. |
| `Localization/` | `LocalizationBundle.swift` — `Bundle.archieLocalized` (SPM vs app) and `String(archie:)`. |
| `Resources/` | `Localizable.xcstrings` |
| `Config/` | Shared constants and `UserDefaults`. |

## Dependencies

- **[SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)** — terminal view and local shell process.

## Privacy & security

- Chat data is stored **locally** (SwiftData). The only outbound traffic is API requests to your configured provider.
- Prefer storing API keys in **Keychain**; do not commit `.env` files with secrets (see `.gitignore`).

## License

[MIT](LICENSE)
