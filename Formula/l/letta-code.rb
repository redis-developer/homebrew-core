class LettaCode < Formula
  desc "Memory-first coding agent"
  homepage "https://docs.letta.com/letta-code"
  url "https://registry.npmjs.org/@letta-ai/letta-code/-/letta-code-0.26.9.tgz"
  sha256 "fb26e7db0d29ebd91c3585eec3cae9fa5729f2cec7f002d20f444277ff98437d"
  license "Apache-2.0"

  bottle do
    sha256               arm64_tahoe:   "cf49fdcff44675a8ca7487e385c3a8db26f57929ec282997d087d82c2c14f433"
    sha256               arm64_sequoia: "af23d0e5b2e79b03893d157e2897badd4eab0873a6d7c1e8f798327b01656afa"
    sha256               arm64_sonoma:  "a244ae8e6fec99180aee5c13592d9fde858da58792f8245b925562dffb1544c4"
    sha256               sonoma:        "cab6632350461a1d3efc6b1892d69f1292522d538821b4cbea567b4e7a69a4e5"
    sha256 cellar: :any, arm64_linux:   "7a5a859748e6bdd59c95d26de38245f7ca2de22070125e71e375dc6bb00ab866"
    sha256 cellar: :any, x86_64_linux:  "ef24066c6c3349fe28b7731a2915fdeb0de5b55cdbadc08ac6e113796c0af9e1"
  end

  depends_on "pkgconf" => :build
  depends_on "glib"
  depends_on "node"
  depends_on "ripgrep"
  depends_on "vips"

  on_macos do
    depends_on "gettext"
  end

  resource "node-gyp" do
    url "https://registry.npmjs.org/node-gyp/-/node-gyp-12.3.0.tgz"
    sha256 "d209963f2b21fd5f6fad1f6341897a98fc8fd53025da36b319b92ebd497f6379"

    livecheck do
      url :url
    end
  end

  def install
    system "npm", "install", *std_npm_args
    bin.install_symlink libexec.glob("bin/*")

    # Remove ripgrep pre-built binaries
    node_modules = libexec/"lib/node_modules/@letta-ai/letta-code/node_modules"
    rm_r(node_modules.glob("@vscode/ripgrep-*"))
    rm_r(node_modules/"@vscode/ripgrep") # keeping separate from previous rm_r to fail if missing

    # Replace node-pty pre-built binaries
    cd node_modules/"node-pty" do
      rm_r(["prebuilds", "third_party"])
      system "npm", "run", "install"
    end

    # Replace sharp pre-built binaries
    rm_r(node_modules.glob("@img/sharp-*"))
    resource("node-gyp").stage do
      system "npm", "install", *std_npm_args(prefix: buildpath/"node-gyp")
      ENV.append_path "NODE_PATH", buildpath/"node-gyp/lib/node_modules"
    end
    cd node_modules/"sharp" do
      ENV["SHARP_FORCE_GLOBAL_LIBVIPS"] = "1"
      system "npm", "run", "build"
      rm_r("src/build/Release/obj.target")

      # help letta.js find source-built sharp
      sharp = Pathname.pwd.glob("src/build/Release/sharp-*.node").first
      (node_modules/"@img"/sharp.basename(".node")).install_symlink sharp => "sharp.node"
    end
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/letta --version")

    output = shell_output("#{bin}/letta --info")
    assert_match "Locally pinned agents: (none)", output
  end
end
