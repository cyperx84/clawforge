class Clawforge < Formula
  desc "Forge and manage fleets of OpenClaw agents"
  homepage "https://github.com/cyperx84/clawforge"
  url "https://github.com/cyperx84/clawforge/archive/refs/tags/v2.1.0.tar.gz"
  sha256 "8a330d297211cd2a5543b73d959046673c8ee0ec9870eff4bffd8fcf50706c5d"
  license "MIT"
  head "https://github.com/cyperx84/clawforge.git", branch: "main"

  depends_on "jq"

  def install
    libexec.install Dir["bin/*"]
    libexec.install Dir["lib"]
    libexec.install Dir["config"]
    libexec.install "VERSION"
    libexec.install "registry"

    (bin/"clawforge").write <<~EOS
      #!/bin/bash
      export CLAWFORGE_DIR="#{libexec}"
      exec "#{libexec}/clawforge" "$@"
    EOS
  end

  test do
    assert_match "clawforge v", shell_output("#{bin}/clawforge version")
    assert_match "Usage:", shell_output("#{bin}/clawforge help")
  end
end
