class Clawforge < Formula
  desc "Multi-mode coding workflow CLI for orchestrating AI coding agents"
  homepage "https://github.com/cyperx84/clawforge"
  url "https://github.com/cyperx84/clawforge/archive/refs/tags/v1.7.0.tar.gz"
  sha256 "1507ed093b836903cb8036ab8a9da603d074681540c9cda5b1551c1a8e7efb58"
  sha256 "1507ed093b836903cb8036ab8a9da603d074681540c9cda5b1551c1a8e7efb58"
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
