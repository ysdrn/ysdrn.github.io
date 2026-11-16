# frozen_string_literal: true

# diary の本文に裸で書いた URL（note.com の記事、雑誌のバックナンバーなど）をリンクにする。
#
# kramdown の GFM 入力は裸の URL を自動でリンクにしない（GitHub の autolink 拡張は未実装）。
# 日記は note と同じ書き方（URL を一行に置く）なので、Amazon 以外の URL が
# 文字のまま出ていた（2026-11-16、2026w46 の note.com と新潮の URL）。
#
# amazon_card.rb のあとに走る（プラグインはファイル名順に読み込まれ、同じフックは登録順）。
# カードの HTML の href="..." や url(...)、Markdown のリンク [..](...)・<...> の中の URL は
# 直前の文字（" ' ( < > = [ /）で除外する。末尾の句読点はリンクに含めない。

module BareUrlAutolink
  URL_RE = %r{(?<![("'<>=\[/])https?://[A-Za-z0-9\-._~:/?#@!$&*+,;=%]+}
  TRAILING = /[.,;:!?]+\z/

  def self.process(content)
    in_fence = false
    content.each_line.map do |line|
      if line =~ /\A\s*(```|~~~)/
        in_fence = !in_fence
        next line
      end
      next line if in_fence

      line.gsub(URL_RE) do |url|
        tail = url[TRAILING] || ''
        url = url.sub(TRAILING, '')
        "<#{url}>#{tail}"
      end
    end.join
  end
end

if defined?(Jekyll)
  Jekyll::Hooks.register :documents, :pre_render do |doc, *_payload|
    next unless doc.collection.label == 'diary' && doc.content
    doc.content = BareUrlAutolink.process(doc.content)
  end
end
