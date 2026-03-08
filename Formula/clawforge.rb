class Clawforge < Formula
  desc "Multi-mode coding workflow CLI for orchestrating AI coding agents"
  homepage "https://github.com/cyperx84/clawforge"
  url "https://github.com/cyperx84/clawforge/archive/refs/tags/v1.6.3.tar.gz"
  sha256 "ea3f82bf78f18be193c7e83ad01fd1031e518d4ad83aca052c5290c80d2bdc5a"
  sha256 "cf0465a4ad2029ea80f677cd91800d062ab6e21583b52dc3fe161e965263ce15"
  sha256 "555c7b03fe52ff1d748ae942d259eea8b362b562d5b2b35cbfa1e40e3bc34597"
  sha256 "240927908d5b2738b2e22156eeb360d09c5b20c3bde04b46a2b11d9de7466eba"
  sha256 "b2d483778e83b9007b22bb4c421c90b71e7343cc4f244d116b99eaa2810dc433"
  sha256 "549b3ebf95c953cd4f366b5a251786c994726761c9d4ed6255b996b6458cf695"
  sha256 "2730fca0066fda9d3c864802c4346ab7c39d0daee39a254cc5cebd2694d4a1db"
  sha256 "a026cb0df5b7c3efae439a9ca912e728843deb56c70441591c9064f81a1041ae"
  sha256 "27cca187828366d138dbde81f99f313e065c656be7073452ccc016eb5dba16db"
  sha256 "ce9da13357fc54d20e59da5851ac04a4ebbff071ec5a7ce1b17b0cbe877b3416"
  sha256 "050e1745af5f64fe017ecc8d533a7f653935b572f45f4c9766f5746a4b58b54e"
  sha256 "4ff8f36c599e81f03291210a6044bd0cce78a953f53eb360f47ce375706104d9"
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
