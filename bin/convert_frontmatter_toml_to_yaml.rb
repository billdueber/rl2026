#!/usr/bin/env ruby
# Convert Hugo front matter in content/posts/*.adoc from TOML to YAML.
#
# Parsing and serialization are done exclusively by battle-tested
# libraries: toml-rb (TomlRB.parse) for TOML and Psych (Hash#to_yaml)
# for YAML. The only string manipulation used is on fence lines
# (+++ / --- detection) and verbatim preservation of date-like scalars
# (String#start_with?/delete_prefix/split with string separators).
# No regular expressions anywhere.
#
# Date/time values are emitted as quoted YAML strings whose text is
# preserved verbatim from the source TOML (TomlRB would otherwise
# normalize them to Time and reshape the text via iso8601).

require 'toml-rb'
require 'yaml'
require 'time'

ROOT = File.expand_path('..', __dir__)
DIR  = File.join(ROOT, 'content', 'posts')

def convert(path)
  lines = File.readlines(path)

  abort "#{path}: does not start with +++ fence" unless lines.first.strip == '+++'

  closing = lines[1..].index { |line| line.strip == '+++' }
  abort "#{path}: no closing +++ fence" unless closing
  closing += 1 # index within full array

  body = lines[1...closing].join
  rest = lines[(closing + 1)..].to_a.join

  front = TomlRB.parse(body) # raises on invalid TOML

  # Preserve date-like scalars verbatim. Find the raw source line for
  # each key TomlRB typed as Time/Date and reuse its exact text.
  date_keys = front.select { |_k, v| v.is_a?(Time) || v.is_a?(Date) }.keys
  raw = {}
  unless date_keys.empty?
    body.lines.each do |line|
      date_keys.each do |key|
        prefix = key + ' = '
        next unless line.start_with?(prefix)

        raw[key] = line.delete_prefix(prefix).split('#').first.strip
      end
    end
  end
  date_keys.each { |key| front[key] = raw[key] || front[key].iso8601 }

  yaml_body = front.to_yaml.delete_prefix("---\n")
  File.write(path, "---\n" + yaml_body + "---\n" + rest)
end

files = Dir[File.join(DIR, '*.adoc')].sort
files.each do |file|
  convert(file)
  puts "converted #{File.basename(file)}"
end
puts "done: #{files.size} files"