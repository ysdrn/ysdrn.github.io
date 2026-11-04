# frozen_string_literal: true

# main.css の cache busting を直す。
# テーマ（al_folio_core）は main.css に jekyll-cache-bust の bust_css_cache を使うが、
# それは `assets/_sass/` の中身をハッシュする。このサイトの CSS は `assets/css/main.scss`
# なので、CSS を変えても `?v=` が変わらず、ブラウザは古い main.css を使い続けていた
# （2026-11-04 にプロフィール欄の CSS が反映されなかった原因）。
# ここでは assets/css/**/*.scss と _sass/** の中身からハッシュを作る。

require 'digest/md5'

module Jekyll
  module CacheBust
    def bust_css_cache(file_name)
      source = @context.registers[:site].source
      files = Dir[File.join(source, 'assets', 'css', '**', '*.scss')] +
              Dir[File.join(source, '_sass', '**', '*')] +
              Dir[File.join(source, 'assets', '_sass', '**', '*')]
      content = files.reject { |f| File.directory?(f) }.sort.map { |f| File.read(f) }.join
      [file_name, '?v=', Digest::MD5.hexdigest(content)].join
    end
  end
end
