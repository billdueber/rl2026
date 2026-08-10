#!/usr/bin/env ruby
# generate_month_archives.rb
#
# Reconciles month-archive stubs for the Robot Librarian Hugo site.
#
# Hugo has no built-in way to render per-month archive pages (its page kinds
# are home/page/section/taxonomy/term/single/list — no date kind), so each
# month needs a real content page at content/archive/<year>/<month>/index.md.
# This script keeps those stubs in sync with the actual posts:
#
#   * Scans content/posts/*.adoc for the TOML frontmatter `date`.
#   * Creates a leaf-bundle stub for every distinct year-month that has at
#     least one (non-draft) post.
#   * Deletes stubs for months that no longer have any posts.
#
# It is idempotent and safe to run before every build (see bin/build.sh).
# Existing stub bodies are preserved — only missing stubs are created, and
# only stubs whose month has no posts are removed.

require "date"
require "fileutils"

ROOT         = File.expand_path("..", __dir__)                    # .../hugo
POSTS_GLOB   = File.join(ROOT, "content", "posts", "*.adoc")
ARCHIVE_ROOT = File.join(ROOT, "content", "archive")

# --- Read the TOML frontmatter block of a content file --------------------
def frontmatter(path)
  content = File.read(path)
  return nil unless content.start_with?("+++")
  content[/\A\+\+\+\r?\n(.*?)\r?\n\+\+\+/m, 1]
end

# --- Parse `date` from frontmatter; returns Date or nil --------------------
# Skips drafts. Accepts `date = 2009-03-30` or a quoted string.
def post_date(path)
  fm = frontmatter(path)
  return nil unless fm
  return nil if fm =~ /^\s*draft\s*=\s*true\s*i?$/i

  raw = fm[/^\s*date\s*=\s*(?:["']?)(\d{4}-\d{2}-\d{2})/, 1]
  raw && Date.strptime(raw, "%Y-%m-%d")
rescue StandardError
  nil
end

# --- 1. Collect distinct months that have at least one post ----------------
months = {}
Dir.glob(POSTS_GLOB).each do |f|
  d = post_date(f)
  months[d.strftime("%Y-%m")] ||= d if d
end

desired = months.keys.sort.map do |key|
  year, month = key.split("-")
  File.join(ARCHIVE_ROOT, year, month, "index.md")
end

# --- 2. Create missing stubs ----------------------------------------------
created = 0
desired.each do |stub|
  next if File.exist?(stub)
  month = File.basename(File.dirname(stub))
  year  = File.basename(File.dirname(File.dirname(stub)))
  first = Date.new(year.to_i, month.to_i, 1)
  FileUtils.mkdir_p(File.dirname(stub))
  File.write(stub, <<~T
    +++
    title = "#{first.strftime("%B %Y")}"
    date = #{first.strftime("%Y-%m-%d")}
    draft = false
    +++
  T
  )
  created += 1
end

# --- 3. Remove stubs for months that now have no posts ---------------------
removed = []
Dir.glob(File.join(ARCHIVE_ROOT, "*", "*", "index.md")).each do |stub|
  next if desired.include?(stub)
  FileUtils.rm_f(stub)
  removed << stub
end

# Prune now-empty year/month directories.
Dir.glob(File.join(ARCHIVE_ROOT, "*")).select { |p| File.directory?(p) }.each do |y|
  Dir.glob(File.join(y, "*")).select { |p| File.directory?(p) }.each do |m|
    FileUtils.rmdir(m) if (Dir.entries(m) - %w[. ..]).empty?
  end
  FileUtils.rmdir(y) if (Dir.entries(y) - %w[. ..]).empty?
end

puts "month archives: #{desired.size} months (#{created} created, #{removed.size} removed)"
