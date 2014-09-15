Pod::Spec.new do |s|

  s.name         = "SoundBankPlayer"
  s.version      = "1.0.0"
  s.summary      = "Sample-based audio player for iOS that uses OpenAL"

  s.description  = <<-DESC
                  This is a sample-based audio player for iOS that uses OpenAL. A "sound bank" can have multiple samples, each covering one or more notes. This allows you to implement a full instrument with only a few samples. It's like SoundFonts but simpler.
                   DESC

  s.homepage     = "https://github.com/hollance/SoundBankPlayer"
  s.license      = { :type => "MIT", :file => "LICENSE.txt" }
  s.author       = { "Matthijs Hollemans" => "mail@hollance.com" }
  s.source       = { :git => "http://github.com/hollance/SoundBankPlayer.git", :tag => "1.0.0" }

  s.source_files  = "SoundBankPlayer/*.{h,m,c}"
end
