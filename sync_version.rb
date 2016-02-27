#!/usr/bin/env ruby

plist_path = File.absolute_path("RileyLink/RileyLink-Info.plist")

canonical_version = `defaults read #{plist_path} CFBundleShortVersionString`.chomp

#bundle_version = `defaults read #{plist_path} CFBundleVersion`.chomp
#if bundle_version != canonical_version
#  puts "Updating CFBundleVersion to #{canonical_version}"
#  `defaults write  #{plist_path} CFBundleVersion -string "#{canonical_version}"`
#end

podspec_text = File.open("RileyLink.podspec",:encoding => "UTF-8").read

match_data = podspec_text.match(/s.version.*=.*\"([\d\.]*)\"/)

if match_data
  podspec_version = match_data[1]
  if podspec_version != canonical_version
    puts "Updating version in RileyLink.podspec to #{canonical_version}"
    `sed -i -e 's/s\.version.*=.*$/s.version      = \"#{canonical_version}\"/' RileyLink.podspec`
  end
else
  puts "Could not find s.version in podspec!"
  exit -1
end
