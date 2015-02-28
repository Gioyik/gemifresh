require 'rubygems'
require 'bundler'
require 'time'
require File.dirname(__FILE__) + '/lib/support'

if ARGV.include?('--help') 
  puts <<-HELP
  Usage: gemifresh [GEMFILE] [LOCKFILE]
    
  Both GEMFILE and LOCKFILE will default to "Gemfile" and "Gemfile.lock" in 
  your current directory. Generally you'll simply invoke gemfresh from your 
  Rails (or similar) project directory.
    
  Gemfresh will list three categories of gems:
    
    "Current" gems are up-to-date.
    
    "Obsolete" gems have a newer version than the one specified in your Gemfile
  
    "Updateable" gems have a newer version, and it is within the version in your Gemfile
    e.g. Gemfile:      '~> 2.2.0'
         Gemfile.lock: 2.2.1
         Latest:       2.2.2
    Running bundle update will attempt to update these gems.

  Just because a gem is updateable or obsolete, doesn't mean it can be 
  updated. There might be dependencies that limit you to specific versions.

  Check the bundler documentation (http://gembundler.com/) for more 
  information on Gemfiles.
  HELP
  exit 1
end

gemfile = ARGV[0] || './Gemfile'
lockfile = ARGV[1] || './Gemfile.lock'
unless File.exists?(gemfile)
  puts "Couldn't find #{gemfile}.\nRun gemfresh with --help if you need more information."
  exit -1
end
unless File.exists?(lockfile)
  puts "Couldn't find #{lockfile}.\nRun gemfresh with --help if you need more information."
  exit -1
end

puts "Checking your Gemfile.\n"

Bundler.settings[:frozen] = true
bundle = Bundler::Dsl.evaluate('./Gemfile', './Gemfile.lock', {})

deps = bundle.dependencies
specs = bundle.resolve
sources = {}
results = { :current => [], :update => [], :obsolete => [] }
count = 0
prereleases = 0
unavailable = 0
untracked = 0

dep_specs = deps.map { |dep| [dep, specs.find { |spec| spec.name == dep.name }] }
dep_specs = dep_specs.select { |dep, spec| !spec.nil? && (spec.source.class == Bundler::Source::Rubygems) }

if deps.empty?
  puts "No top-level RubyGem dependencies found in your Gemfile.\nRun gemfresh with --help if you need more information."
  exit true 
end

print "Hitting up your RubyGems sources: "
dep_specs.each do |dep, spec|
  name = dep.name

  gemdata = versions = false
  spec.source.remotes.each do |remote|
    begin 
      next if remote.nil?
      reader = sources[remote]
      next if reader == :unavailable
      reader = sources[remote] = RubyGemReader.new(remote) if reader.nil?

      gemdata = reader.get("/api/v1/gems/#{name}.yaml")
      gemdata = YAML.load(gemdata)
      next if (gemdata && gemdata['version'].nil?)
      
      versions = reader.get("/api/v1/versions/#{name}.yaml")
      versions = YAML.load(versions)
      
      break unless !gemdata || !versions
            
    rescue SourceUnavailableError => sae
      sources[remote] = :unavailable
    end
  end

  if !gemdata || !versions || gemdata['version'].nil?
    unavailable =+ 1
    print "x"
 
  else
    diff = SpecDiff.new(dep, spec, gemdata, versions)
    results[diff.classify] << diff
    prereleases +=1 if diff.prerelease?
    count += 1
    print "."
  end

  STDOUT.flush
end
puts " Done!"

if unavailable > 0
  puts "\nCouldn't get data for #{unavailable} gem#{unavailable == 1 ? '' : 's'}. It might be the RubyGem source is down or unaccessible. Give it another try in a moment."
end

if prereleases > 0
  puts "\nYou have #{prereleases} prerelease gem#{prereleases == 1 ? '' : 's'}. Prereleases will be marked with a '*'."
end

puts "\nThe following Gems are:"
ages = results.values.flatten.group_by(&:build_age)
{:none => 'No build dates available', :month1 => 'less than a month old', :month6 => 'less than 6 months old', :year1 => 'less than a year old', :more => 'more than a year old'}.each_pair do |key, value|
  next if ages[key].nil?
  puts "-- #{value}:"
  puts ages[key].map(&:to_s).join(', ')
end

if results[:current].empty?
  puts "\nYou don't have any current gems."
else
  puts "\nThe following gems at the most current version: "
  puts results[:current].map(&:to_s).join(', ')
end

if results[:update].empty?
  puts "\nYou don't have any updatable gems."
else
  puts "\nThe following gems are locked to older versions, but your Gemfile allows for the current version: "
  results[:update].each do |diff| 
    puts "    #{diff}, with #{diff.dep.requirement} could allow #{diff.version_available}"
  end
  puts "Barring dependency issues, these gems could be updated to current using 'bundle update'."
end

if results[:obsolete].empty?
  puts "\nYou don't have any obsolete gems."
else
  puts "\nThe following gems are obsolete: "
  results[:obsolete].each do |diff|
    released = diff.version_build_date(diff.version_available)
    released = released.nil? ? '.' : ", #{released.strftime('%d %b %Y')}."

    suggest = diff.suggest
    suggest = suggest.nil? ? '' : "Also consider version #{suggest}."
    
    puts "    #{diff} is now at #{diff.version_available}#{released} #{suggest}"    
  end
end

exit results[:obsolete].empty?
