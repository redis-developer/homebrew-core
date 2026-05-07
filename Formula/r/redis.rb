class Redis < Formula
  desc "Persistent key-value database, with built-in net interface"
  homepage "https://redis.io/"
  url "https://download.redis.io/releases/redis-8.6.3.tar.gz"
  sha256 "9f54d4458c52be5472cdd1347d737f1d488b520fc3d0911cba47302de8d836e2"
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
    sha256 cellar: :any,                 arm64_tahoe:   "69857547948e7ca8f6324ec169a9d14acccd0d892be8a850e7b4015052f216de"
    sha256 cellar: :any,                 arm64_sequoia: "a08f94c910880ef852e95c4fbefa30371c3e765e66f6cd76c196b86166bf145a"
    sha256 cellar: :any,                 arm64_sonoma:  "89ce05fd284686569e992c1d31337aa36686f2ae8e1986076c34e7957d2b5261"
    sha256 cellar: :any,                 sonoma:        "b84b11b36d00d866b6449f894df3f7dedccc2c274936cd1e5d8e4cc2e9167262"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "2c02ead2d7544babd9dd9c29728ce8a3be6af6ddd1c1693f4fd33a588f837e7c"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "ef817043bed2c5cd27463aa30f6a0e130232891e14527433dddead55366bad60"
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

  resource "redisjson" do
    url "https://github.com/redisjson/redisjson.git",
    revision: "107144fd2c0a6b325108352bf83ed6e6f731a20f"
  end

  resource "redisbloom" do
    url "https://github.com/redisbloom/redisbloom.git",
    revision: "60c96b3f11dcf71d4707137a3452bbb6941493dd"
  end

  resource "redistimeseries" do
    url "https://github.com/redistimeseries/redistimeseries.git",
    revision: "5d7c61c9f861b5cb83989463595c2c9f6b2bfe63"
  end

  resource "redisearch" do
    url "https://github.com/redisearch/redisearch.git",
    revision: "30204860f145da013ba042e0824df6d344aef4ce"
  end

  def install
    openssl = Formula["openssl@3"]

    system "make", "install", "PREFIX=#{prefix}", "CC=#{ENV.cc}", "BUILD_TLS=yes"

    resource("redisjson").stage do
      # Build the module
      system "gmake", "all"
      lib.install Dir.glob("bin/*-release/rejson.so").first
    end

    resource("redisbloom").stage do
      # Build the module
      system "gmake", "all"
      lib.install Dir.glob("bin/*-release/redisbloom.so").first
    end

    resource("redistimeseries").stage do
      # Set compiler flags for OpenSSL
      ENV.append "CFLAGS", "-I#{openssl.opt_include}"
      ENV.append "CXXFLAGS", "-I#{openssl.opt_include}"
      ENV.append "CPPFLAGS", "-I#{openssl.opt_include}"
      ENV.append "LDFLAGS", "-L#{openssl.opt_lib}"
      # Build the module
      system "gmake", "build", "openssl_prefix=#{openssl.opt_prefix}", "OPENSSL_PREFIX=#{openssl.opt_prefix}"
      lib.install Dir.glob("bin/*-release/redistimeseries.so").first
    end

    resource("redisearch").stage do
      # RediSearch has been verified to support runtime CPU detection for SIMD optimizations
      ENV.runtime_cpu_detection
      # Build the module
      system "gmake", "build", "OPENSSL_ROOT_DIR=#{openssl.opt_prefix}", "IGNORE_MISSING_DEPS=1"
      lib.install Dir.glob("bin/*-release/search-community/redisearch.so").first
    end

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

  def post_install
    # Set execute permissions on module files
    %w[redisbloom.so rejson.so redisearch.so redistimeseries.so].each do |file|
      chmod 0755, lib/file
    end

    # Add loadmodule directives to redis.conf
    redis_conf = Pathname.new(HOMEBREW_PREFIX)/"etc/redis.conf"

    if redis_conf.exist?
      conf_content = redis_conf.read

      # Add loadmodule directives for each Redis module
      %w[redisbloom.so rejson.so redisearch.so redistimeseries.so].each do |file|
        module_path = opt_lib/file
        loadmodule_line = "loadmodule #{module_path}"

        next if conf_content.include?(loadmodule_line)

        ohai "Adding #{file} module to redis.conf"
        File.open(redis_conf, "a") do |f|
          f.write "\n# #{file} module\n"
          f.write "#{loadmodule_line}\n"
        end
        conf_content = redis_conf.read
      end
    else
      opoo "redis.conf not found at #{redis_conf}"
    end
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
