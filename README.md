# osnip

One hotkey. Drag a region. Paste a WebP that is usually under 100 KB.

osnip is a small macOS command-line tool. It opens the same snipping crosshair you get from Cmd+Shift+4, converts the capture to WebP, aims for a file under 100 KB, and puts it on the clipboard. Raycast then shows one line:

```
Copied · 412 KB → 68 KB (−84%)
```

Paste it into your notes app, a GitHub comment, Slack, or anywhere else that accepts image files.

## Why

A macOS screenshot of a normal window is often 500 KB to several megabytes as PNG. Notes, issue trackers and chat tools store whatever you paste. osnip shrinks the capture before it reaches the clipboard, and keeps text pixel-perfect whenever it can.

## Requirements

- macOS 14 (Sonoma) or newer
- [Homebrew](https://brew.sh)
- [Raycast](https://www.raycast.com) for the hotkey setup described here. Any other hotkey tool works too, see [Using another hotkey tool](#using-another-hotkey-tool).

## Install

```
brew install --HEAD spiritanand/tap/osnip
```

`--HEAD` builds the newest commit. It is required until osnip has its first tagged release; from then on plain `brew install spiritanand/tap/osnip` works.

This builds osnip from source with the Swift toolchain that ships with the Xcode Command Line Tools, and installs `cwebp` (Homebrew's `webp` formula) as a dependency.

Check that it worked:

```
osnip --version
```

## Set up the hotkey in Raycast

1. Open Raycast, then open its settings with Cmd+comma.
2. Go to **Extensions**, press the **+** button, and choose **Add Script Directory**.
3. Pick the directory Homebrew printed after the install. You can print it again with:

   ```
   echo "$(brew --prefix)/opt/osnip/share/osnip/raycast"
   ```

   In the file picker, press Cmd+Shift+G and paste that path.
4. Back in **Extensions**, find **Optimized Snip** under **Script Commands**.
5. Click its **Record Hotkey** field and press Cmd+Shift+0, or any combination you like.

## Allow Screen Recording

macOS only lets an app read the screen after you allow it. The permission belongs to the app that starts the capture, which is Raycast, not osnip.

1. Press your hotkey once.
2. If macOS asks, or if osnip shows `Allow Screen Recording for Raycast`, open **System Settings > Privacy & Security > Screen & System Audio Recording**. osnip opens that page for you when it detects the problem.
3. Turn on **Raycast**. macOS may ask you to quit and reopen Raycast.

macOS asks you to confirm this permission again from time to time. That is normal for any screenshot tool that is not made by Apple.

## Use it

1. Press the hotkey.
2. Drag to select a region. Press Space to switch to window mode and click a window. Press Escape to cancel.
3. Wait for the `Copied` line. It appears in well under a second for most snips.
4. Paste.

## First-run checklist

Do this once after installing. It covers the parts no automated test can reach.

- [ ] The hotkey opens the crosshair.
- [ ] Escape shows nothing and leaves your clipboard as it was.
- [ ] A snip shows `Copied · … → … (−…%)` and pastes as an image.
- [ ] The pasted file is the small one. In your notes app, export or locate the attachment and compare it with the newest file in `~/Library/Caches/osnip/`:

  ```
  ls -lt ~/Library/Caches/osnip | head -3
  shasum -a 256 ~/Library/Caches/osnip/<newest file> <exported attachment>
  ```

  The sizes and the hashes should match. If they do not, that app re-encodes pasted images and the savings are lost there.

## What the line means

| Line | Meaning |
|---|---|
| `Copied · 412 KB → 68 KB (−84%)` | The WebP is on the clipboard. Sizes are the original PNG and the result. |
| `Copied · 3 KB` | Copied, but the result was not meaningfully smaller than the original. |
| `Copied original · Optimization failed` | Something went wrong while shrinking. The untouched PNG was copied so you lose nothing. |
| `Allow Screen Recording for Raycast` | See [Allow Screen Recording](#allow-screen-recording). |
| `Couldn't capture` | The capture failed for another reason. Try again. |
| `Couldn't copy` | The file could not be stored or put on the clipboard. |
| `osnip is not installed` | Raycast found the script but not the `osnip` program. Reinstall with Homebrew. |
| nothing | You pressed Escape, or a previous snip was still being processed. |

## How it decides what to ship

100 KB is a target, not a hard limit. osnip never fails just because an image is big.

It runs four encodes at the same time and keeps the first one in this list that is under 100 KB:

1. Full size, lossless. Pixel-perfect. This wins for most snips of text and interface.
2. Full size, lossy, with a quality floor so text does not turn to mush.
3. Half size, lossless. This is what rescues a large capture of text.
4. Half size, lossy.

If none is under 100 KB, the smallest one ships and the line shows its real size.

Before encoding, the capture is converted to the sRGB color space. Screenshots carry your display's color profile, and dropping it without converting would make colors look washed out.

## Where files go

The clipboard holds a reference to a real file, so osnip keeps the last 50 captures in:

```
~/Library/Caches/osnip/
```

Older captures are deleted automatically. You never need to clean this folder, and you can empty it at any time.

## Using another hotkey tool

Raycast is only the launcher. `osnip` is an ordinary program that takes no arguments, prints one line, and exits. Any tool that can run a command from a hotkey works: Hammerspoon, Keyboard Maestro, BetterTouchTool, skhd, Karabiner-Elements, or the Shortcuts app.

Two things to know:

- Point the tool at the full path, since hotkey tools often run with a minimal `PATH`:

  ```
  echo "$(brew --prefix)/bin/osnip"
  ```

- Screen Recording permission then belongs to that tool instead of Raycast. The permission line still says "Raycast"; allow your tool in the same settings page.

## Limits

- **Sites that only accept PNG, JPEG or GIF on paste** ignore a pasted WebP file. Drag the file from `~/Library/Caches/osnip/` instead, or use the normal macOS screenshot for those.
- **Telegram** turns any `.webp` file into a sticker.
- **Apps that read pixels instead of files** re-encode the image themselves, so the size savings do not carry over there.
- **Holding Control while you finish the selection** is a feature of the macOS capture screen: it sends the raw screenshot straight to the clipboard and skips osnip.
- There are no settings in this version. The budget, the format and the cache size are fixed.

## Troubleshooting

**Nothing happens when I press the hotkey.** Check that the hotkey is recorded on **Optimized Snip** in Raycast, and that `osnip --version` works in a terminal.

**The crosshair never appears and I see `Allow Screen Recording for Raycast`.** Turn on Raycast under Screen & System Audio Recording, then quit and reopen Raycast.

**I always get `Copied original · Optimization failed`.** `cwebp` is missing. Run `brew install webp`.

**A crosshair is stuck on screen.** A previous run was interrupted while the selection was open. Press Escape, then use the hotkey again.

**The pasted image is a sticker, or the paste does nothing.** See [Limits](#limits).

## Install from source

```
git clone https://github.com/spiritanand/osnip.git
cd osnip
brew install webp
make install
```

`make install` builds a release binary and copies it to `~/.local/bin/osnip`. Use `make install PREFIX=/some/dir` to put it elsewhere. In Raycast, add the repository's `raycast` directory as the script directory.

## Development

```
make build   # release build
make test    # run the test suite
```

The tests use the real `cwebp` and `sips`, write only to temporary directories, and use a private pasteboard, so they never touch your clipboard.

[ARCHITECTURE.md](ARCHITECTURE.md) explains how the code is organized and introduces the Swift it uses, for readers who are new to the language.

## License

[MIT](LICENSE)
