class Filebrowser < Formula
  desc "Web File Browser"
  homepage "https://filebrowser.org/"
  url "https://github.com/filebrowser/filebrowser/archive/refs/tags/v2.63.9.tar.gz"
  sha256 "609b32b4dae4cc564326d127e79ad05fd23570c06cfda6535f44b25288a44e11"
  license "Apache-2.0"
  head "https://github.com/filebrowser/filebrowser.git", branch: "master"

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "bbbf3b316a29604e6a1ffbbfabd73f6bac65474a80863281a7f094d052e740a3"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "9bb9bbe0a55efc72aad42b5589100b43acc09d680ebc3a52b2b49425bae2cc4b"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "4300b4ab043423428b658c708f8c54e028f0f36b3d7cd75a27619a79e67d1523"
    sha256 cellar: :any_skip_relocation, sonoma:        "bdec29db0d566b419c26ac034a1ae006f35bcde493e10c72bcb04f685033a860"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "82c7baf25a50704672fbca904a17baafa5e5304ab02ec8ba0878db22948cdded"
    sha256 cellar: :any,                 x86_64_linux:  "191140a12c783ff4b7163ac7dd2c052c550e1c3a994a33890003c1afa6b157c0"
  end

  depends_on "go" => :build

  def install
    ldflags = %W[
      -s -w
      -X github.com/filebrowser/filebrowser/v2/version.Version=#{version}
      -X github.com/filebrowser/filebrowser/v2/version.CommitSHA=#{tap.user}
    ]

    system "go", "build", *std_go_args(ldflags:)

    generate_completions_from_executable(bin/"filebrowser", shell_parameter_format: :cobra)
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/filebrowser version")

    system bin/"filebrowser", "config", "init"
    assert_path_exists testpath/"filebrowser.db"

    output = shell_output("#{bin}/filebrowser config cat 2>&1")
    assert_match "Using database: #{testpath}/filebrowser.db", output
  end
end
