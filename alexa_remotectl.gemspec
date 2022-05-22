Gem::Specification.new do |s|
  s.name = 'alexa_remotectl'
  s.version = '0.4.0'
  s.summary = 'Experimental project to play or pause Alexa\'s ' +
      'music player using the SPA API'
  s.authors = ['James Robertson']
  s.files = Dir["lib/alexa_remotectl.rb"]
  s.add_runtime_dependency('clipboard', '~> 1.3', '>=1.3.6')
  s.signing_key = '../privatekeys/alexa_remotectl.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/alexa_remotectl'
end
