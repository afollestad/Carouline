## Debug

- Wrap every file here in `#if DEBUG`, and reach it from elsewhere only inside `#if DEBUG` blocks, so Release never names a debug type.
- Never persist a setting. Read them from the argument domain alone, so an override can't outlive the session that set it.
- Give every setting a launch argument, documented on `DebugSettings.init(arguments:)`.
- Keep debug sample data out of the real store: `SampleStore` lives under `tmp` and is reset each launch.
- Don't unit-test debug tooling. It never ships and breaks visibly on first use.
