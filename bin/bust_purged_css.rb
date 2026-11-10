#!/usr/bin/env ruby
# frozen_string_literal: true

# purgecss のあとで、HTML の中の CSS の `?v=` を「削ったあとの CSS ファイルの中身」のハッシュに付け替える。
#
# なぜ要るか: `?v=` はビルド時に元の scss から計算する（_plugins/cache_bust_fix.rb）。ところが purgecss は
# 「いま HTML に出ているクラス」で CSS を削るので、scss が同じでも記事の中身しだいで main.css の中身が変わる。
# すると URL が同じまま中身だけ変わり、ブラウザは古い（削られた）CSS を使い続ける。
# 2026-11-10、タグのない状態で notes のタグナビの CSS が削られ、タグを付けたあとも古い CSS が残って
# ナビが素の箇条書きに見えた。
#
# 使い方（CI の deploy.yml、purgecss の直後）: ruby bin/bust_purged_css.rb [_site]

require 'digest/md5'

site = ARGV[0] || '_site'
css_dir = File.join(site, 'assets', 'css')
hashes = Dir[File.join(css_dir, '*.css')].to_h do |path|
  [File.basename(path), Digest::MD5.file(path).hexdigest]
end
abort "no css in #{css_dir}" if hashes.empty?

pattern = %r{(/assets/css/(#{hashes.keys.map { |n| Regexp.escape(n) }.join('|')}))\?v=[0-9a-f]+}
changed = 0
Dir[File.join(site, '**', '*.html')].each do |html|
  text = File.read(html, mode: 'r:UTF-8') # CI のロケールが C でも読めるように
  next unless text.include?('/assets/css/')

  replaced = text.gsub(pattern) { "#{Regexp.last_match(1)}?v=#{hashes.fetch(Regexp.last_match(2))}" }
  next if replaced == text

  File.write(html, replaced, mode: 'w:UTF-8')
  changed += 1
end
puts "bust_purged_css: #{changed} html files, #{hashes.size} css files"
