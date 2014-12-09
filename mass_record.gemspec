$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "mass_record/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "mass_record"
  s.version     = MassRecord::VERSION
  s.authors     = ["Nathan Hanna"]
  s.email       = ["jnathanhdev@gmail.com"]
  s.homepage    = "https://github.com/jnathanh/mass_record"
  s.summary     = "A Ruby on Rails library to help with mass database operations like insert, update, save, validations, etc (much faster than typical ActiveRecord Interactions..."
  s.description = "A Ruby on Rails library to help with mass database operations like insert, update, save, validations, etc (much faster than typical ActiveRecord Interactions"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4"
  s.add_dependency "colorize"

  s.add_development_dependency "sqlite3"
  s.add_development_dependency "mysql2"
  s.add_development_dependency "tiny_tds"
  s.add_development_dependency "activerecord-sqlserver-adapter"
  s.add_development_dependency "random_jpg"

end
