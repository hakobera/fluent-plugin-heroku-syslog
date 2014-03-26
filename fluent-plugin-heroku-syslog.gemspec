# -*- encoding: utf-8 -*-
Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-heroku-syslog"
  gem.version       = "0.0.1"
  gem.authors       = ["Kazuyuki Honda"]
  gem.email         = ["hakobera@gmail.com"]
  gem.description   = %q{fluent plugin to drain heroku syslog}
  gem.summary       = %q{fluent plugin to drain heroku syslog}
  gem.homepage      = "https://github.com/hakobera/fluent-plugin-heroku-syslog"
  gem.license       = "APLv2"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency "fluentd", ">= 0.10.43"
  gem.add_development_dependency "rake"
end
