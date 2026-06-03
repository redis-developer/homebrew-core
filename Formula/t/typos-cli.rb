class TyposCli < Formula
  desc "Source code spell checker"
  homepage "https://github.com/crate-ci/typos"
  url "https://github.com/crate-ci/typos/archive/refs/tags/v1.47.1.tar.gz"
  sha256 "bc7bdeff13c8410a59bafc0705868e7e6bfd8a97525dc08b94d7879514beea3d"
  license any_of: ["Apache-2.0", "MIT"]

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "90e17906d63873b8322dde399c2796dcd4b1d301bc3ad24e94818802b78413ce"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "ba49521807728b19be7e0996b8c530fd0606bb7fbd084cf0ce1ec46397d02f6c"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "6ef9f9e9fbaedb9c1b2902512b577eaa68782573d2228fba3557359dc4a02b7d"
    sha256 cellar: :any_skip_relocation, sonoma:        "c4f29d829326012716255a06fc5eaa9b3b6bb701824905415b3ef636c94650af"
    sha256 cellar: :any,                 arm64_linux:   "1b6a7e15da0c057ca37694c020fd8b8401e5aeffa8a35d8ff7b1f2bb0b00afb0"
    sha256 cellar: :any,                 x86_64_linux:  "4c1165247213cb45ed108f4c056eb5a281d91e875ac9f0e02ede87f2f9a6c314"
  end

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args(path: "crates/typos-cli")
  end

  test do
    assert_match "error: `teh` should be `the`", pipe_output("#{bin}/typos -", "teh", 2)
    assert_empty pipe_output("#{bin}/typos -", "the")
  end
end
