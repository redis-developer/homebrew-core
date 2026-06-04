class Skillshare < Formula
  desc "Sync skills across AI CLI tools"
  homepage "https://skillshare.runkids.cc"
  url "https://github.com/runkids/skillshare/archive/refs/tags/v0.20.6.tar.gz"
  sha256 "ae116734d4f0b2f049b1afc5269b72c0b1c265bbe7a30204e97ad094cf1cb134"
  license "MIT"
  head "https://github.com/runkids/skillshare.git", branch: "main"

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "b0097d8448a70261781892f2376492254cc72ed613501e52ec4151a561f18c9c"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "b0097d8448a70261781892f2376492254cc72ed613501e52ec4151a561f18c9c"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "b0097d8448a70261781892f2376492254cc72ed613501e52ec4151a561f18c9c"
    sha256 cellar: :any_skip_relocation, sonoma:        "20a7acfbb18fc3414b756bb5480c34393d647197a5929d3f1d778e0ff6095972"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "6cd4d8d59c113d99df0e6681615b9d9a474ff2ea730ffd291854997ac0a12b76"
    sha256 cellar: :any,                 x86_64_linux:  "b07eca858248fac14c3c8ea06fe2402db535c6b9d5f44f7b61f4a28ba15af444"
  end

  depends_on "go" => :build

  def install
    # Avoid building web UI
    ui_path = "internal/server/dist"
    mkdir_p ui_path
    (buildpath/"#{ui_path}/index.html").write "<!DOCTYPE html><html><body><h1>UI not built</h1></body></html>"

    ldflags = %W[
      -s -w
      -X main.version=#{version}
    ]
    system "go", "build", *std_go_args(ldflags:), "./cmd/skillshare"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/skillshare version")

    assert_match "config not found", shell_output("#{bin}/skillshare sync 2>&1", 1)
  end
end
