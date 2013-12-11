require 'shellwords'

namespace 'test' do

  desc 'creates a database suitable for testing'
  task 'setup_db' do
    sh "mysql --user=travis --database=racktables_test -h 127.0.0.1 < #{File.expand_path('spec/testdata/fresh_installed.sql')}"
  end

  desc 'runs the tests'
  task 'test' do
    sh "env 'RACKTABLES_DB=mysql2://travis@127.0.0.1/racktables_test?encoding=utf8' rspec"
  end

  task :default => 'test:test'

end

task :default => ['test:setup_db','test:test']
