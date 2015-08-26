#!/usr/bin/env ruby

require 'json'

plist_path = File.absolute_path("RileyLink/RileyLink-Info.plist")

canonical_version = `defaults read #{plist_path} CFBundleShortVersionString`.chomp
bundle_version = `defaults read #{plist_path} CFBundleVersion`.chomp

podspec = JSON.parse(`pod ipc spec RileyLink.podspec`)

podspec_version = podspec["version"]

if bundle_version != canonical_version
  puts "Need to update CFBundleVersion to #{canonical_version}!"
  exit -1
end

if podspec_version != canonical_version
  puts "Need to update version in RileyLink.podspec to #{canonical_version}!"
  exit -1
end
