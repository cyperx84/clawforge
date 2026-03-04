class Clawforge < Formula
  desc "Multi-mode coding workflow CLI for orchestrating AI coding agents"
  homepage "https://github.com/cyperx84/clawforge"
  url "https://github.com/cyperx84/clawforge/archive/refs/tags/v1.3.0.tar.gz"
  sha256 "e961b184df80e82b17db3b0aa4e4f474bcb7d6d1aafd97d187906b0090f2ce7b"
  sha256 "4364bb00aadf4b4f762be5e859a5be33a3f561ded134610691f1ac4cc4492b6e"
  sha256 "6da402969628cc5a0dbafdcfca2596bced80692a714672ccb9e39c45f121465c"
  # sha256 will be filled by CI
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
