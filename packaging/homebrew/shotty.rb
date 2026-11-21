cask "shotty" do
  version "0.2.0"
  sha256 "REPLACE_WITH_RELEASE_SHA256"

  url "https://github.com/remidiy/Shotty/releases/download/v#{version}/Shotty-#{version}.zip"
  name "Shotty"
  desc "Sends new screenshots and screen recordings straight into AI apps"
  homepage "https://github.com/remidiy/Shotty"

  depends_on macos: ">= :tahoe"

  app "Shotty.app"

  zap trash: [
    "~/Library/Preferences/com.remidiy.shotty.plist",
  ]
end
