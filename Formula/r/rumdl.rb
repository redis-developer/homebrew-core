class Rumdl < Formula
  desc "Markdown Linter and Formatter written in Rust"
  homepage "https://github.com/rvben/rumdl"
  url "https://github.com/rvben/rumdl/archive/refs/tags/v0.2.6.tar.gz"
  sha256 "bc14c4629672841679c65233a04d97d4c114e53da989cef722740bb4b98e551b"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "6ff21a7c395ed68bbba59f4ed22bdb76b18aefb3f6032cd5354420885af18579"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "b044a14156b1a4d6178ddaedd06d10fdb543a778e6d520c1a3e3c57ef3024f79"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "5545e3da2831e9ffbede6d15c5584fbb806f4906c8a5558d0cb4db52145e6a16"
    sha256 cellar: :any_skip_relocation, sonoma:        "7da1077000a78771a10d13d1a3c182b0e8e6ca2bf020dc5f5a76b579c05ea5c4"
    sha256 cellar: :any,                 arm64_linux:   "6f49170f80b42ac0eebee83baf09869eca677f585bc956c32a94907d38254c2a"
    sha256 cellar: :any,                 x86_64_linux:  "72425c38d4eab53c51533069e017d4118c5893bb76a3e70d6bb32b5d7d48964f"
  end

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
    generate_completions_from_executable(bin/"rumdl", "completions")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/rumdl version")

    (testpath/"test-bad.md").write <<~MARKDOWN
      # Header 1
      body
    MARKDOWN
    (testpath/"test-good.md").write <<~MARKDOWN
      # Header 1

      body
    MARKDOWN

    assert_match "Success", shell_output("#{bin}/rumdl check test-good.md")
    assert_match "MD022", shell_output("#{bin}/rumdl check test-bad.md 2>&1", 1)
    assert_match "Fixed", shell_output("#{bin}/rumdl fmt test-bad.md")
    assert_equal (testpath/"test-good.md").read, (testpath/"test-bad.md").read
  end
end
