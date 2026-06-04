class KosliCli < Formula
  desc "CLI for managing Kosli"
  homepage "https://docs.kosli.com"
  url "https://github.com/kosli-dev/cli/archive/refs/tags/v2.24.1.tar.gz"
  sha256 "d8307ed196fa60bd2978b48ce8577dcacf22e124a3f71b8376b7bd109a1bdd38"
  license "MIT"
  head "https://github.com/kosli-dev/cli.git", branch: "main"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "610b60de703d6d2e6cd116dc93c21ca678e5db5528dc6d71b4d4bf32b19982e8"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "5f007d77fe865c4d50238374922618b33f21b4987a9eeaa56fd99626219adfbd"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "fe1f7c2f93355e7669088f32b41af2e81e3bd6d72915f806b7e4c51707c247b3"
    sha256 cellar: :any_skip_relocation, sonoma:        "d9a5c9670fada8e5ee68b8605610e48b30902cfb5ed84895008cc2e405dd1861"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "9da457afb56c77afea29a859652694cd0864053380f799045b01e17404a5670c"
    sha256 cellar: :any,                 x86_64_linux:  "c73e859a450cc63cff6c168c8fead31fcf58bdeb4406e9aa932fed023e9cee8d"
  end

  depends_on "go" => :build

  def install
    ldflags = %W[
      -s -w
      -X github.com/kosli-dev/cli/internal/version.version=#{version}
      -X github.com/kosli-dev/cli/internal/version.gitCommit=#{tap.user}
      -X github.com/kosli-dev/cli/internal/version.gitTreeState=clean
    ]
    system "go", "build", *std_go_args(output: bin/"kosli", ldflags:), "./cmd/kosli"

    generate_completions_from_executable(bin/"kosli", shell_parameter_format: :cobra)
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/kosli version")

    assert_match "OK", shell_output("#{bin}/kosli status")
  end
end
