class Clawforge < Formula
  desc "Forge and manage fleets of OpenClaw agents"
  homepage "https://github.com/cyperx84/clawforge"
  url "https://github.com/cyperx84/clawforge/archive/refs/tags/v2.0.1.tar.gz"
  sha256 "9568edc52e32c7afb648fb9f63c548d97aa829cd371099feb680388668cd85e8"
  sha256 "577cdf0e2cac9030e6ef20e6ba6a582c3a810bb43043b4fbc44c288996f514d7"
  license "MIT"
  head "https://github.com/cyperx84/clawforge.git", branch: "main"

  depends_on "jq"
  depends_on "tmux"
  depends_on "gh"

  def install
    # Install shell scripts
    libexec.install Dir["bin/*"]
    libexec.install Dir["lib"]
    libexec.install Dir["tui"]
    libexec.install Dir["config"]
    libexec.install "VERSION"
    libexec.install "registry"

    # Create wrapper that sets CLAWFORGE_DIR
    (bin/"clawforge").write <<~EOS
      #!/bin/bash
      export CLAWFORGE_DIR="#{libexec}"
      exec "#{libexec}/clawforge" "$@"
    EOS

    # Dashboard binary
    bin.install libexec/"clawforge-dashboard"
  end

  test do
    assert_match "clawforge v", shell_output("#{bin}/clawforge version")
    assert_match "Usage:", shell_output("#{bin}/clawforge help")
  end
end
