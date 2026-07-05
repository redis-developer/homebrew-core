class Redis < Formula
  desc "Persistent key-value database, with built-in net interface"
  homepage "https://redis.io/"
  url "https://github.com/TalBarYakar/redis/releases/download/redis-docker-6/redis-full.tar.gz"
  sha256 "d9bf883aecdd42b925bc464e850cc64f3b12dff2060a87184617690fe4874bc4"
  license all_of: [
    "AGPL-3.0-only",
    "BSD-2-Clause", # deps/jemalloc, deps/linenoise, src/lzf*
    "BSL-1.0", # deps/fpconv
    "MIT", # deps/lua
    any_of: ["CC0-1.0", "BSD-2-Clause"], # deps/hdr_histogram
  ]
  revision 1
  compatibility_version 1
  head "https://github.com/redis/redis.git", branch: "unstable"

  livecheck do
    url "https://download.redis.io/releases/"
    regex(/href=.*?redis[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  no_autobump! because: :bumped_by_upstream

  bottle do
    sha256 cellar: :any,                 arm64_tahoe:   "2a6d55f7fe58eed0accecb5b313ad04e40931e4d5a9bb0970b0ddc1aee8bac7f"
    sha256 cellar: :any,                 arm64_sequoia: "8aa8ff647ad7bdf807ea222a3d10c06a59cb550a339e9724bc75cbcd1a4f251d"
    sha256 cellar: :any,                 arm64_sonoma:  "b483b7c9b4b107512ecb359d98e494cc224c0a14318a04ba97ce9223335e39a0"
    sha256 cellar: :any,                 sonoma:        "07d051d7a255d7d6a535b46387cc8977b4d3bf1798cb67b3a6d078ef5c4c3343"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "7dbc95a096a5c160e02efde18bc84ac2c3a36933a4d55b9c0799f988ea1299ed"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "6a0fbaf3633e962f39ef7248321086e1206881a8d1ef141497e482d648e476dd"
  end

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "cmake" => :build
  depends_on "coreutils" => :build
  depends_on "libtool" => :build
  depends_on "llvm@18" => :build
  depends_on "python@3.14" => :build
  depends_on "rust" => :build
  depends_on "openssl@3"

  on_macos do
    depends_on "make" => :build # Needs Make 4.0+
  end

  conflicts_with "valkey", because: "both install `redis-*` binaries"

  def install
    openssl = Formula["openssl@3"]

    system "gmake", "deploy", "PREFIX=#{prefix}", "CC=#{ENV.cc}", "BUILD_TLS=yes", "REDISEARCH_GENERATE_HEADERS=0"

    %w[run db/redis log].each { |p| (var/p).mkpath }

    # Fix up default conf file to match our paths
    inreplace "redis.conf" do |s|
      s.gsub! "/var/run/redis_6379.pid", var/"run/redis.pid"
      s.gsub! "dir ./", "dir #{var}/db/redis/"
      s.sub!(/^bind .*$/, "bind 127.0.0.1 ::1")
    end

    etc.install "redis.conf"
    etc.install "sentinel.conf" => "redis-sentinel.conf"
  end

  service do
    run [opt_bin/"redis-server", etc/"redis.conf"]
    keep_alive true
    error_log_path var/"log/redis.log"
    log_path var/"log/redis.log"
    working_dir var
  end

  test do
    system bin/"redis-server", "--test-memory", "2"
    %w[run db/redis log].each { |p| assert_path_exists var/p, "#{var/p} doesn't exist!" }

    # Test that all modules can be loaded
    %w[redisbloom.so rejson.so redisearch.so redistimeseries.so].each do |file|
      module_path = lib/file
      assert_path_exists module_path, "#{file} module not found at #{module_path}"

      # Test that the module loads successfully
      output = shell_output("#{bin}/redis-server --loadmodule #{module_path} --test-memory 2 2>&1", 1)
      assert_match(/Module.*loaded from/, output)
    end
  end
end
