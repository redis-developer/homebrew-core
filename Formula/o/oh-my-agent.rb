class OhMyAgent < Formula
  desc "Portable multi-agent harness for .agents-based skills and workflows"
  homepage "https://github.com/first-fluke/oh-my-agent"
  url "https://registry.npmjs.org/oh-my-agent/-/oh-my-agent-8.28.0.tgz"
  sha256 "98f9dc0f0f374c1d718a5a9cccfdcf2ccfa2198444e9215d773c168148057ff3"
  license "MIT"

  bottle do
    sha256 cellar: :any, arm64_tahoe:   "dbd344631351e15ca3b33554444a36463e5429ce21f52d588514ebaaabbbafcf"
    sha256 cellar: :any, arm64_sequoia: "c06ca5f11f975c3b2265ed13e6e4063e0d920b76c13aaae8ed97f33cad4d0b77"
    sha256 cellar: :any, arm64_sonoma:  "c06ca5f11f975c3b2265ed13e6e4063e0d920b76c13aaae8ed97f33cad4d0b77"
    sha256 cellar: :any, sonoma:        "e7aa74089e317c853d6c91aa91a40a577355d447ebcde73b2ec36444f547e053"
    sha256 cellar: :any, arm64_linux:   "2150be5e9b58967550899513f28d26ad67d9a8c579cd5472edbbb352fa78f990"
    sha256 cellar: :any, x86_64_linux:  "a63762b4bfb13bb2394ee786402e69befb45e1175d80e209949e1daf93798298"
  end

  depends_on "node"

  def install
    system "npm", "install", *std_npm_args

    node_modules = libexec/"lib/node_modules/oh-my-agent/node_modules"
    # Remove incompatible pre-built `bare-fs`/`bare-os`/`bare-url` binaries
    os = OS.kernel_name.downcase
    arch = Hardware::CPU.intel? ? "x64" : Hardware::CPU.arch.to_s
    node_modules.glob("{bare-fs,bare-os,bare-url}/prebuilds/*")
                .each { |dir| rm_r(dir) if dir.basename.to_s != "#{os}-#{arch}" }

    bin.install_symlink Dir[libexec/"bin/*"]
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/oh-my-agent --version")

    output = JSON.parse(shell_output("#{bin}/oh-my-agent memory:init --json"))
    assert_empty output["updated"]
    assert_path_exists testpath/".serena/memories/orchestrator-session.md"
    assert_path_exists testpath/".serena/memories/task-board.md"
  end
end
