Gem::Specification.new do |gem|
  gem.name    = 'racktables_api'
  gem.version = '0.0.1'
  gem.date    = Time.now.strftime("%Y-%m-%d")

  gem.summary = "Use all the gits"

  gem.authors  = ['Hannes Georg']
  gem.email    = 'hannes.georg@xing.com'
  gem.homepage = 'https://github.com/xing/racktables_api'

  gem.files = Dir['lib/**/*'] & `git ls-files -z`.split("\0")

  # core:
  gem.add_dependency 'sequel'
  gem.add_dependency 'rack'
  gem.add_dependency 'multi_json'
  gem.add_dependency 'ipaddress'
  gem.add_dependency 'addressive'

  # api key generator:
  gem.add_dependency 'slim'
  gem.add_dependency 'sass'
  gem.add_dependency 'sinatra'

  # ldap authentication:
  gem.add_dependency 'net-ldap'

  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "simplecov"
  gem.add_development_dependency 'cucumber'
end
