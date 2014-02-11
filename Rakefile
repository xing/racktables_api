require 'shellwords'

namespace 'test' do

  desc 'creates a database suitable for testing'
  task 'setup_db' do
    sh "mysql --user=travis --database=racktables_test -h 127.0.0.1 < #{File.expand_path('spec/testdata/fresh_installed.sql')}"
  end

  desc 'run cucumber'
  task 'cucumber' do
    sh "env 'RACKTABLES_DB=mysql2://travis@127.0.0.1/racktables_test?encoding=utf8' cucumber"
  end

  desc 'run rspec'
  task 'rspec' do
    sh "env 'RACKTABLES_DB=mysql2://travis@127.0.0.1/racktables_test?encoding=utf8' rspec"
  end

  desc 'runs the tests'
  task 'test' do
    only = ENV.fetch('RACKTABLES_TEST','rspec,cucumber').split(',')
    only.each do |t|
      Rake::Task["test:#{t}"].invoke
    end
  end

  task :default => 'test:test'

end

task :default => ['test:setup_db','test:test']
