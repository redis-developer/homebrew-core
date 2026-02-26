class Redis < Formula
  desc "Persistent key-value database, with built-in net interface"
  homepage "https://redis.io/"
  url "https://download.redis.io/releases/redis-8.6.1.tar.gz"
  sha256 "6873fc933eeb7018aa329e868beac7228695f50c0d46f236a4ff1a6d7f7bb5b6"
  license all_of: [
    "AGPL-3.0-only",
    "BSD-2-Clause", # deps/jemalloc, deps/linenoise, src/lzf*
    "BSL-1.0", # deps/fpconv
    "MIT", # deps/lua
    any_of: ["CC0-1.0", "BSD-2-Clause"], # deps/hdr_histogram
  ]
  revision 1
  head "https://github.com/redis/redis.git", branch: "unstable"

  livecheck do
    url "https://download.redis.io/releases/"
    regex(/href=.*?redis[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  bottle do
    sha256 cellar: :any,                 arm64_tahoe:   "9c8066d1449fe4409ceac586524fabe20ffbc5d0550dd51c6854cd44fb36dc18"
    sha256 cellar: :any,                 arm64_sequoia: "47545c5a6b4111af674b84fb0ea731451a77c43ab7d14b30202c7952d56f455f"
    sha256 cellar: :any,                 arm64_sonoma:  "da7ab72d1d8f23e7d4faf24c8819128eb209ca613d5baf7d5b093385e4051081"
    sha256 cellar: :any,                 sonoma:        "4741855b02343ac4c68bde8aee23e6865cbdeb5ba2d16c67b46b991db06adc03"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "dcc94d4c8530780cd3cb0f4bda5952d3ce97c088a970ab561c114eeaf06b1efb"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "8e8351a1d086b3a541b28fff6ae7aad46033045fd9440a707d10b972e1bbc41f"
  end

  depends_on "openssl@3"
  depends_on "redisbloom"
  depends_on "redisearch"
  depends_on "redisjson"
  depends_on "redistimeseries"

  conflicts_with "valkey", because: "both install `redis-*` binaries"

  def install
    system "make", "install", "PREFIX=#{prefix}", "CC=#{ENV.cc}", "BUILD_TLS=yes"

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
    # Add loadmodule directives to redis.conf
    redis_conf = Pathname.new(HOMEBREW_PREFIX)/"etc/redis.conf"

    if redis_conf.exist?
      conf_content = redis_conf.read

      # Add loadmodule directives for each Redis module
      {
        "redisbloom" => "redisbloom.so",
        "redisjson" => "rejson.so",
        "redisearch" => "redisearch.so",
        "redistimeseries" => "redistimeseries.so",
      }.each do |formula_name, file|
        module_path = Formula[formula_name].opt_lib/file
        loadmodule_line = "loadmodule #{module_path}"

        next if conf_content.include?(loadmodule_line)

        ohai "Adding #{formula_name} module to redis.conf"
        File.open(redis_conf, "a") do |f|
          f.write "\n# #{formula_name} module\n"
          f.write "#{loadmodule_line}\n"
        end
        conf_content = redis_conf.read
      end
    else
      opoo "redis.conf not found at #{redis_conf}"
    end
  end

  def caveats
    # Extract major.minor version (e.g., "8.4" from "8.4.0")
    redis_major_minor = version.to_s.split(".")[0, 2].join(".")
    mismatched_modules = []

    # Check each module formula for version compatibility
    %w[redisbloom redisjson redisearch redistimeseries].each do |formula_name|
      begin
        module_formula = Formula[formula_name]
        module_version = module_formula.version.to_s
        module_major_minor = module_version.split(".")[0, 2].join(".")

        if module_major_minor != redis_major_minor
          mismatched_modules << "  - #{formula_name}: v#{module_version} (incompatible with Redis v#{version})"
        end
      rescue FormulaUnavailableError
        # Module formula not installed or not available
      end
    end

    return if mismatched_modules.empty?

    <<~EOS
      Warning: Some Redis modules have incompatible major versions:
      #{mismatched_modules.join("\n")}

      Redis modules must have matching major.minor versions (e.g., 8.4.x).
      Please update the modules to compatible versions.
    EOS
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
    {
      "redisbloom" => "redisbloom.so",
      "redisjson" => "rejson.so",
      "redisearch" => "redisearch.so",
      "redistimeseries" => "redistimeseries.so",
    }.each do |formula_name, file|
      module_path = Formula[formula_name].opt_lib/file
      assert_path_exists module_path, "#{formula_name} module not found at #{module_path}"

      # Test that the module loads successfully
      output = shell_output("#{bin}/redis-server --loadmodule #{module_path} --test-memory 2 2>&1", 1)
      assert_match "Module", output
    end
  end
end
