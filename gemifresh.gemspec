Gem::Specification.new do |s|
  s.name        = 'gemifresh'
  s.version     = '1.0'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Giovanny Andres Gongora Granada']
  s.email       = ['gioyik@gmail.com']
  s.homepage    = 'https://github.com/Gioyik/gemifresh'
  s.summary     = 'Checks if your Gemfile gem deps are update.'
  s.description = 'Scans Gemfiles to check gem updates.'

  s.license = "MIT"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['.']

  s.add_runtime_dependency 'bundler', '~> 1.7'
end
