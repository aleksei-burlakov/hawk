# Copyright (c) 2009-2015 Tim Serong <tserong@suse.com>
# See COPYING for license.

Rails.application.config.tap do |config|
  config.assets.version = "1.0"

  config.assets.precompile = [
    "locale*.css", "locale*.js",
    "gettext.css", "gettext.js",
    "application.css","application.js",
    "authentication.css", "authentication.js",
    "dashboard.css", "dashboard.js",
    "ie.css", "ie.js",
    "vendor.css", "vendor.js",
    "*.jpg", "*.png", "*.gif", "*.svg",
    "*.ico", "*.eot", "*.woff", "*.woff2", "*.ttf"
  ]

  config.assets.paths << config.root.join(
    "vendor",
    "assets",
    "fonts"
  )

  config.assets.paths << config.root.join(
    "vendor",
    "assets",
    "images"
  )
end
