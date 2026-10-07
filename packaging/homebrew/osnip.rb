class Osnip < Formula
  desc "Snip a screen region to a WebP under 100 KB, straight to the clipboard"
  homepage "https://github.com/spiritanand/osnip"
  url "https://github.com/spiritanand/osnip/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "a2f5e334cf45064b7827a30602e2d02917ff545f5745e3986d0e329e80ec9709"
  license "MIT"
  head "https://github.com/spiritanand/osnip.git", branch: "main"

  depends_on macos: :sonoma
  depends_on "webp"

  def install
    system "swift", "build", "--disable-sandbox", "-c", "release"
    bin.install ".build/release/osnip"
    pkgshare.install "raycast"
  end

  def caveats
    <<~EOS
      Bind osnip to a hotkey in Raycast:
        1. Raycast Settings > Extensions > + > Add Script Directory
        2. Choose #{opt_pkgshare}/raycast
        3. Find "Optimized Snip" and record a hotkey, for example Cmd+Shift+0
      On first use, allow Screen Recording for Raycast in System Settings.
    EOS
  end

  test do
    assert_match(/\A\d+\.\d+\.\d+\n\z/, shell_output("#{bin}/osnip --version"))
  end
end
