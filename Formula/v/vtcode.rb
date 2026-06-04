class Vtcode < Formula
  desc "CLI Semantic Coding Agent"
  homepage "https://github.com/vinhnx/vtcode"
  url "https://static.crates.io/crates/vtcode/vtcode-0.119.0.crate"
  sha256 "ba07ddad9acc02174f12c6691a141bafa50f425f19f70600ec24589ffe5c2175"
  license "MIT"
  head "https://github.com/vinhnx/vtcode.git", branch: "main"

  livecheck do
    throttle 5
  end

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "d02729cb89dc322c0b916ce59d53481bf5cba1274bed547bfca5c8362700f315"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "988d80d0e4b3dda0404b194c3f282394105aaeb07745d4092797a303f9246af2"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "e75a5d4db880bdc68634106df7cc835d725d96336306f183939340212b1deee3"
    sha256 cellar: :any_skip_relocation, sonoma:        "b5dd04f716941984e045f49b49468bac7e3facb283bea456473ca77a8f303225"
    sha256 cellar: :any,                 arm64_linux:   "19ff17c49441883923abc41da1670e7ea0e3baa9ca700fdeeaa0ac6bfe428fcc"
    sha256 cellar: :any,                 x86_64_linux:  "a2e852275580741b1de81d7cae92dfeb31116e74677fab4e2f8044dd30743e67"
  end

  depends_on "pkgconf" => :build
  depends_on "rust" => :build
  depends_on "ripgrep"

  on_linux do
    depends_on "openssl@4" => :build
  end

  def install
    ENV["OPENSSL_DIR"] = Formula["openssl@4"].opt_prefix if OS.linux?
    system "cargo", "install", *std_cargo_args
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/vtcode --version")

    ENV["OPENAI_API_KEY"] = "test"
    output = shell_output("#{bin}/vtcode models list --provider openai")
    assert_match "OPENAI", output
  end
end
