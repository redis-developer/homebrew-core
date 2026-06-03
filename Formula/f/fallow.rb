class Fallow < Formula
  desc "Codebase intelligence for TypeScript and JavaScript"
  homepage "https://docs.fallow.tools"
  url "https://github.com/fallow-rs/fallow/archive/refs/tags/v2.87.0.tar.gz"
  sha256 "f4efd638595dac3063acd7b174871142c6db791044a6bd602baedb27972d971b"
  license "MIT"
  head "https://github.com/fallow-rs/fallow.git", branch: "main"

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "c008a1cf95a32ed73bfea8e5f6408b5d2e068fcb04ab9155b4ed2cafa0cb0fba"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "21173b9fb8463f4e6b97ab1f2942ebe052dd47627bbbdb27ae561712db30fb7e"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "76806fb8a71b20f4b373adc41dee0fc95374bdfc31688c480a702f15500746a1"
    sha256 cellar: :any_skip_relocation, sonoma:        "0baa81781e01b5249d0604bc9a725e09fcf290e0e432a834cc6d1429e0e8aeba"
    sha256 cellar: :any,                 arm64_linux:   "b69d0f93ec190395849a8f1935c4e95bdafa71ee5df25dd390e5d032ec163c67"
    sha256 cellar: :any,                 x86_64_linux:  "ba66f733c83635a8c30c27c471dd13a3cb4e41c22b324284697b3d07fc8af53e"
  end

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args(path: "crates/cli")
  end

  test do
    (testpath/"package.json").write <<~JSON
      {
        "scripts": {
          "start": "node src/index.js"
        },
        "dependencies": {}
      }
    JSON

    (testpath/"node_modules").mkpath
    (testpath/"src").mkpath
    (testpath/"src/index.js").write <<~JS
      export const used = 1;
      console.log(used);
    JS
    (testpath/"src/unused.js").write <<~JS
      export const unused = 1;
    JS

    system "git", "init", "-q"

    output = JSON.parse(shell_output("#{bin}/fallow --format json --quiet --no-cache"))
    assert_equal 1, output.dig("check", "summary", "unused_files")
    assert_kind_of Hash, output.fetch("dupes")
    assert_kind_of Numeric, output.dig("health", "vital_signs", "dead_file_pct")
    assert_match version.to_s, shell_output("#{bin}/fallow --version")
  end
end
