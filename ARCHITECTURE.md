# How osnip works

This document is for someone who wants to read or change the code, including someone who has never written Swift. It has three parts: the flow, a short introduction to the Swift you will meet in this repository, and a tour of every file.

## The flow

```
hotkey
  └─ raycast/osnip.sh            sets PATH, runs the osnip program
       └─ main.swift             reads arguments, runs a Snip, prints one line
            └─ Snip.run()
                 1. RunLock            only one run at a time
                 2. ScreenCapture      runs /usr/sbin/screencapture -i
                 3. ColorNormalizer    runs sips to convert to sRGB
                 4. WebPEncoder        runs four cwebp encodes at once, picks one
                 5. CaptureStore       moves the winner into ~/Library/Caches/osnip
                 6. Clipboard          puts the file on the pasteboard
                 7. CaptureStore       deletes captures beyond the newest 50
                 └─ returns an Outcome, which knows its line and exit code
```

osnip is mostly a conductor. Three programs that already exist on your Mac or in Homebrew do the heavy work: `screencapture` takes the picture, `sips` converts colors, `cwebp` encodes WebP. The one job osnip does itself is the clipboard write, because no command-line program can put a typed file-and-image item on the pasteboard.

## Swift in fifteen minutes

Everything below appears in this codebase. Each idea has a real example.

### A package has targets

`Package.swift` describes the project. It declares three targets:

- `OsnipCore`, a library with all the logic, in `Sources/OsnipCore`.
- `osnip`, the program you run, in `Sources/osnip`. It is a few lines that call the library.
- `OsnipCoreTests`, the tests, in `Tests/OsnipCoreTests`.

Splitting the library from the program is what lets the tests call the logic directly.

### `let`, `var`, and types

`let` declares a constant, `var` a variable. The type comes after a colon, and Swift usually works it out for you.

```swift
let kilobytes = max(1, Int((Double(bytes) / 1000).rounded()))
```

### Functions and argument labels

Swift functions name their arguments at the call site. An underscore means "no label here".

```swift
func add(_ file: URL, fileExtension: String, capturedAt date: Date = Date()) throws -> URL
```

You call it as `store.add(file, fileExtension: "webp")`. The third argument has a default value, so you can leave it out. `capturedAt` is the label the caller writes and `date` is the name used inside the function. `-> URL` is the return type.

### `struct` and `enum`

A `struct` groups values and the functions that work on them. Most types here are structs: `CaptureStore`, `Clipboard`, `WebPEncoder`, `Snip`.

An `enum` is a value that is exactly one of a fixed list of cases. `Outcome` is the best example:

```swift
public enum Outcome: Equatable, Sendable {
    case copied(originalBytes: Int, optimizedBytes: Int)
    case copiedOriginal
    case cancelled
    ...
}
```

The `copied` case carries two numbers with it. These are called associated values. A `switch` over an enum must handle every case, and the compiler refuses to build if you forget one. That is why adding a new outcome is safe: the compiler points at every place that needs a decision.

An enum with no cases, like `ByteCount` or `Shell`, is used as a plain namespace for functions.

### Optionals

A type followed by `?` may hold a value or nothing (`nil`). `URL?` is "a URL or nothing". Swift will not let you use an optional as if it were always there. You unwrap it first:

```swift
guard let cwebp = locateEncoder() else { return nil }
```

`guard let` says: if there is a value, call it `cwebp` and continue; otherwise leave. Related tools you will see are `if let`, `??` (use this fallback when nil), and `?.` (keep going only if there is a value).

### Errors: `throws`, `try`, `try?`

A function marked `throws` can fail. You must write `try` in front of each call that can fail.

```swift
try FileManager.default.moveItem(at: file, to: destination)
```

`try?` turns a failure into `nil` instead of an error. osnip uses it where the reaction to every kind of failure is the same:

```swift
guard let stored = try? store.add(file, fileExtension: imageType.fileExtension),
      clipboard.publish(stored, as: imageType)
else { return false }
```

Read that as: store the file, then put it on the clipboard; if storing fails for any reason, or the clipboard write does not succeed, report that publishing did not work.

Functions that can only succeed or fail, with nothing useful to say about why, skip errors altogether. `optimize` returns an optional image, and `makeSRGBCopy` and `Clipboard.publish` return a `Bool`.

### `guard` and early exit

`guard condition else { leave }` keeps the main path of a function unindented. The checks sit at the top and the work follows.

### `defer`

`defer { ... }` schedules code to run when the current scope ends, however it ends. osnip uses it to remove its temporary directory and to stop encoder processes:

```swift
defer { try? FileManager.default.removeItem(at: workDirectory) }
```

### Closures: functions as values

A closure is a function you can store in a variable or pass along. Its type is written `(Input) -> Output`. This is the single most important idea for understanding `Snip`:

```swift
var capture: (URL) -> CaptureResult
var screenRecordingIsGranted: () -> Bool
```

`Snip` does not call `screencapture` itself. It calls whatever `capture` function it was given. The real program gives it the real one in `Snip.live()`. The tests give it a fake that copies a prepared image into place. That is how the whole flow is tested without a person dragging a rectangle.

Short closures use `$0` for their first argument:

```swift
capture: { ScreenCapture().captureInteractively(to: $0) }
```

### Collections: `map`, `filter`, `first`, `sorted`

Instead of loops, Swift code often chains transformations. From `ToolLocator`:

```swift
return (pathDirectories + fallbackDirectories)
    .map { URL(fileURLWithPath: $0).appendingPathComponent(name) }
    .first(where: isExecutableRegularFile)
```

Turn each directory into a candidate path, then return the first one that passes the check. `isExecutableRegularFile` is a small function defined just below it; passing a function by name works wherever a closure is expected. The check rejects directories, because macOS also reports a searchable directory as "executable".

### String interpolation

`"\(kilobytes) KB"` inserts a value into a string.

### `URL` and `Data`

A `URL` says where something is. In osnip it is nearly always a file on disk, written `file:///Users/you/…` when turned into text. A `Data` is a block of raw bytes in memory. `Clipboard.publish` uses both: it puts the file's `URL` on the pasteboard so apps can find the file, and it reads the file into a `Data` so apps that want the image itself get its bytes.

```swift
guard let imageBytes = try? Data(contentsOf: file) else { return false }
item.setString(file.absoluteString, forType: .fileURL)
item.setData(imageBytes, forType: imageType.pasteboardType)
```

### `public`, `private`, `static`

`public` makes something visible outside the library. Only what the program in `main.swift` needs is public: `Snip`, `Outcome`, `Invocation` and the version. `private` hides something inside its file or type. With no keyword, it is visible inside the library and to the tests, which is the right level for everything else. `static` means the function or value belongs to the type itself rather than to an instance, so you call `ByteCount.formatted(1234)` without creating a `ByteCount`.

### Running other programs

Foundation's `Process` starts another program. `Shell.run` waits for it and collects what it printed on standard error. `Shell.start` returns immediately so several can run at once. That second form is how four `cwebp` encodes run in parallel, with no threads in osnip's own code.

### C functions

Swift can call C functions from the operating system directly. `RunLock` uses `open`, `flock` and `close` because Foundation has no file-lock API.

## File by file

All paths are under `Sources/OsnipCore/` unless noted.

**`Sources/osnip/main.swift`** is the program. It turns the arguments into an `Invocation`, and for a plain `osnip` it runs `Snip.live().run()`, prints the outcome's line if there is one, and exits with the outcome's code.

**`Invocation.swift`** maps arguments to intent: no arguments means snip, `--version` and `--help` print, anything else is rejected with `EX_USAGE`, the conventional exit code 64 for a command used wrongly.

**`Snip.swift`** is the conductor. `run()` takes the lock, creates a temporary work directory, calls the capture, and branches on the result. `publishCapture` tries to optimize; `optimize` returns nothing when any step of it fails, and then the original PNG is copied instead. `publish` stores a file, puts it on the clipboard and prunes. Every path ends in an `Outcome`. `Snip.live()` builds the real configuration.

**`Outcome.swift`** lists everything a run can end as, with the exact line Raycast shows and the exit code. The wording lives in this one place.

**`ByteCount.swift`** formats sizes the way Finder does: `68 KB`, `1.4 MB`.

**`RunLock.swift`** allows one run per user at a time, using an exclusive lock on a file in the temporary directory. A second run sees the lock and exits quietly. The kernel releases the lock when the process ends, even if it crashes.

**`ScreenCapture.swift`** runs `screencapture -i -o -t png <file>` and classifies what happened: a complete PNG means captured; no file, no error text and a normal exit means the user pressed Escape; anything else is a failure.

**`ScreenRecordingPermission.swift`** asks macOS whether screen access is granted, and can trigger the system prompt and open the right page in System Settings. It is only consulted after a capture has failed.

**`ImageFile.swift`** answers three questions about a file: how many bytes, how many pixels, and whether it is a complete PNG. The last one checks the final 12 bytes, because the system image library decodes a truncated PNG without complaint.

**`ColorNormalizer.swift`** runs `sips --matchTo` to write an sRGB copy of the capture. If that fails, osnip does not encode the unconverted image; it copies the original instead.

**`WebPEncoder.swift`** holds the heart of the tool.

- `Candidate.inPreferenceOrder` lists the four encodes: full lossless, full lossy, half lossless, half lossy.
- `CandidateSelection.winner` is the rule as a pure function: the first candidate that fits the budget wins; if none fits, the smallest wins, with ties going to the earlier candidate.
- `WebPEncoder.race` starts all four `cwebp` processes, waits for them in preference order, and stops as soon as one fits. Before it returns, it terminates and waits for every process it started, so nothing is left running.
- `arguments(for:)` builds the `cwebp` command line for a candidate.

**`CaptureStore.swift`** owns `~/Library/Caches/osnip/`. `add` moves a file in under a timestamped name and never overwrites. `prune` keeps the file just added plus the newest 49 others.

**`Clipboard.swift`** writes one pasteboard item with two representations: the file's URL and the image bytes. Browsers and Electron apps take the file. It reads the bytes before clearing the pasteboard, so a file that cannot be read leaves your previous clipboard intact. Only a write that the system rejects after the clearing can leave the clipboard empty.

**`Shell.swift`** and **`ToolLocator.swift`** are helpers: run a program, and find `cwebp` on the `PATH` or in Homebrew's directories.

**`Version.swift`** holds the version string.

Outside the Swift package:

- `raycast/osnip.sh` is the Raycast script command. The `# @raycast.` lines are metadata Raycast reads, not ordinary comments.
- `packaging/homebrew/osnip.rb` is the Homebrew formula.
- `Makefile` wraps build, test and install. The test target adds flags that Swift Testing needs when only the Command Line Tools are installed.

## How the tests work

Tests live in `Tests/OsnipCoreTests` and use Swift Testing: a function marked `@Test` is a test, and `#expect(...)` checks a condition.

They exercise real things wherever possible: the real `cwebp` and `sips`, real files in temporary directories, a private pasteboard with a random name so your clipboard is never touched, and a private lock file. Three things are replaced with fakes because the real ones need a person or would open system dialogs: the interactive capture, the permission check, and the permission prompt.

`Fixture.swift` builds test images in code, pixel by pixel, so the repository carries no binary test files.

Run everything with `make test`.

## Where to learn more

- [A Swift Tour](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/guidedtour/): the official half-hour overview. Start here.
- [The Swift Programming Language](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/): the full book. The chapters on Optionals, Enumerations, Closures and Error Handling cover most of what this codebase uses.
- [Getting started with Swift](https://www.swift.org/getting-started/) and [Build a command-line tool](https://www.swift.org/getting-started/cli-swiftpm/): how packages, `swift build` and `swift run` fit together.
- [100 Days of Swift](https://www.hackingwithswift.com/100): a free, paced course if you want practice.
- [Swift Testing](https://developer.apple.com/documentation/testing): the test framework used here.
- [Process](https://developer.apple.com/documentation/foundation/process) and [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard): the two Apple APIs osnip leans on most.
- [cwebp](https://developers.google.com/speed/webp/docs/cwebp): every encoder flag in `WebPEncoder.swift`.
- [Raycast script commands](https://github.com/raycast/script-commands): the format of `raycast/osnip.sh`.

A good first exercise: change the separator in `Outcome.swift`, run `make test`, and read the tests that fail.
