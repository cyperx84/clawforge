class Clawforge < Formula
  desc "Forge and manage fleets of OpenClaw agents"
  homepage "https://github.com/cyperx84/clawforge"
  url "https://github.com/cyperx84/clawforge/archive/refs/tags/v3.1.0.tar.gz"
  sha256 "93a6890113541a2a973a1eed873c9eea0aa4d9fa33c978e52b29cbe34bde8841"
  license "MIT"
  head "https://github.com/cyperx84/clawforge.git", branch: "main"

  depends_on "go" => :build

  def install
    ldflags = %W[
      -s -w
      -X github.com/cyperx84/clawforge/cmd.Version=#{version}
    ]
    system "go", "build", *std_go_args(ldflags: ldflags), "."
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/clawforge version")
    assert_match "Usage:", shell_output("#{bin}/clawforge help")
  end
end
