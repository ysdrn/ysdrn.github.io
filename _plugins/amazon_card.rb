# frozen_string_literal: true

# Amazon アフィリエイトリンク → note.com 風カード
#
# 本文中で Amazon の URL（amazon.co.jp / amzn.to / amzn.asia）が 1 行に単独で
# 置かれていると、ビルド時にカード HTML に置き換える。
#
# 商品名・著者・画像 URL は _data/amazon_cache.json から読むだけで、
# ビルド中に Amazon へは一切アクセスしない（GitHub Actions のデータセンター IP は
# Amazon の bot 対策で弾かれるため、ビルドが Amazon の機嫌に左右されないようにする）。
# キャッシュは自分の Mac で `ruby bin/amazon_cache.rb` を実行して作り、git に入れる。
# .githooks/pre-commit がこれを自動で行う（`git config core.hooksPath .githooks`）。
#
# キャッシュにない URL は、URL のスラッグから推定した商品名と（書籍なら）ISBN から
# 引ける旧式の書影 URL で簡易カードにし、ビルドログに警告を出す。
# amzn.to などの短縮 URL がキャッシュにないときだけ、短縮サービス（bit.ly）に転送先を
# 1 回聞いて ASIN とスラッグを得る。Amazon 本体には触らない。
#
# 価格は表示しない。Amazon アソシエイト参加要件 2(b) は、価格の表示を Amazon が
# 提供するリンクか Creators API 経由のものに限っている（スクレイピングした価格は不可）。

require 'json'
require 'cgi'
require 'net/http'
require 'uri'

module AmazonCard
  AMAZON_URL_RE = %r{^[ \t]*(https?://(?:www\.)?amazon\.co\.jp/[^\s<>]+|https?://amzn\.(?:to|asia)/[^\s<>]+|https?://link\.amazon(?:\.co\.jp)?/[^\s<>]+)[ \t]*$}
  SHORT_URL_RE  = %r{\Ahttps?://(?:amzn\.(?:to|asia)|link\.amazon(?:\.co\.jp)?)/}
  CACHE_FILE    = '_data/amazon_cache.json'
  # ISBN-10 を ASIN に持つ書籍だけが引ける旧式の書影エンドポイント（該当なしは 1x1 GIF）
  LEGACY_IMAGE  = 'https://images-fe.ssl-images-amazon.com/images/P/%s.09._SL500_.jpg'

  class << self
    # { 'items' => { asin => {...} }, 'links' => { short_url => asin } }
    def load_cache(source)
      path = File.join(source, CACHE_FILE)
      return empty_cache unless File.exist?(path)

      data = JSON.parse(File.read(path, encoding: "UTF-8"))
      # 旧形式（asin => item のフラットな hash）を読めるようにしておく
      data = { 'items' => data, 'links' => {} } unless data.key?('items')
      data['links'] ||= {}
      data
    rescue JSON::ParserError => e
      warn "AmazonCard: #{CACHE_FILE} を読めません: #{e.message}"
      empty_cache
    end

    def empty_cache
      { 'items' => {}, 'links' => {} }
    end

    def save_cache(source, cache)
      path = File.join(source, CACHE_FILE)
      sorted = {
        'items' => cache['items'].sort.to_h,
        'links' => cache['links'].sort.to_h,
      }
      File.write(path, JSON.pretty_generate(sorted) + "\n")
    end

    def extract_asin(url)
      return unless url
      return $1.upcase if url =~ %r{/dp/([A-Z0-9]{10})(?:[/?#]|$)}i
      return $1.upcase if url =~ %r{/gp/product/([A-Z0-9]{10})(?:[/?#]|$)}i
      return $1.upcase if url =~ %r{/gp/aw/d/([A-Z0-9]{10})(?:[/?#]|$)}i
      return $1.upcase if url =~ %r{/exec/obidos/ASIN/([A-Z0-9]{10})(?:[/?#]|$)}i
      nil
    end

    def short_url?(url)
      url =~ SHORT_URL_RE ? true : false
    end

    def isbn10?(asin)
      asin.to_s =~ /\A\d{9}[\dX]\z/ ? true : false
    end

    # amazon.co.jp/<スラッグ>/dp/ASIN のスラッグから商品名を推定する（キャッシュ未作成時の保険）
    def title_from_url(url)
      return unless url =~ %r{amazon\.co\.jp/([^/?#]+)/dp/}
      slug = CGI.unescape($1)
      return if slug =~ /\A(gp|dp|exec|s|b|o)\z/i
      slug.tr('-', ' ').strip
    end

    # URL → [asin, item or nil]
    def lookup(url, cache)
      asin = extract_asin(url) || cache['links'][url]
      return [nil, nil] unless asin
      [asin, cache['items'][asin]]
    end

    # 短縮 URL の転送先を短縮サービスにだけ聞く（amazon.co.jp には進まない）。失敗したら nil
    def resolve_short(url, hops = 2)
      current = url
      hops.times do
        return current if current =~ /amazon\.co\.jp/
        uri = URI(current)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        http.open_timeout = 5
        http.read_timeout = 5
        resp = http.request(Net::HTTP::Head.new(uri))
        loc = resp['location']
        return nil unless resp.is_a?(Net::HTTPRedirection) && loc
        current = URI.join(current, loc).to_s
      end
      current =~ /amazon\.co\.jp/ ? current : nil
    rescue StandardError => e
      warn "AmazonCard: #{url} の転送先を取れない: #{e.message}"
      nil
    end

    def fallback_item(url, asin, resolved_url = nil)
      item = { 'asin' => asin, 'title' => title_from_url(resolved_url || url) || "Amazon.co.jp の商品（#{asin}）" }
      item['image'] = format(LEGACY_IMAGE, asin) if isbn10?(asin)
      item
    end

    def render_card(url, item)
      href   = CGI.escapeHTML(url)
      title  = CGI.escapeHTML(item['title'].to_s)
      author = item['author'].to_s.strip
      image  = item['image']

      author_html = author.empty? ? '' : %(\n    <span class="amazon-card-author">#{CGI.escapeHTML(author)}</span>)
      # 書影のリンクは本文リンクと同じ先なので、支援技術からは隠す（名前のないリンクにしない）
      image_html = if image
        %(\n  <a class="amazon-card-image" href="#{href}" rel="noopener nofollow sponsored" target="_blank" aria-hidden="true" tabindex="-1">) +
        %(<span style="background-image:url(#{CGI.escapeHTML(image)})"></span></a>)
      else
        ''
      end

      <<~HTML
        <div class="amazon-card">
          <a class="amazon-card-body" href="#{href}" rel="noopener nofollow sponsored" target="_blank">
            <strong class="amazon-card-title">#{title}</strong>#{author_html}
            <span class="amazon-card-domain">amazon.co.jp</span>
            <div class="amazon-card-button">
              <span class="amazon-card-button-label">Amazon.co.jpで購入する</span>
            </div>
          </a>#{image_html}
        </div>
      HTML
    end

    # 本文中の URL をカードに置換。missing には未キャッシュの URL が溜まる
    def process_content(content, cache, missing = [])
      content.gsub(AMAZON_URL_RE) do |match|
        url = $1
        asin, item = lookup(url, cache)
        resolved = nil
        if asin.nil? && short_url?(url)
          resolved = resolve_short(url)
          asin = extract_asin(resolved)
          cache['links'][url] = asin if asin # このビルドの間だけ覚える（ファイルには書かない）
          item = cache['items'][asin] if asin
        end
        if asin.nil?
          missing << url
          next match
        end
        unless item
          missing << url
          item = fallback_item(url, asin, resolved)
        end
        render_card(url, item)
      end
    end
  end
end

if defined?(Jekyll)
  module AmazonCard
    @missing = {}
    @cache = nil

    class << self
      attr_reader :missing

      def site_cache(site)
        @cache ||= load_cache(site.source)
      end

      def reset!
        @cache = nil
        @missing = {}
      end

      def note_missing(urls, path)
        urls.each { |u| (@missing[u] ||= []) << path }
      end
    end
  end

  Jekyll::Hooks.register :site, :after_reset do |_site|
    AmazonCard.reset!
  end

  convert = lambda do |doc, *_payload|
    next unless doc.content && doc.content =~ AmazonCard::AMAZON_URL_RE

    missing = []
    doc.content = AmazonCard.process_content(doc.content, AmazonCard.site_cache(doc.site), missing)
    AmazonCard.note_missing(missing, doc.relative_path) unless missing.empty?
  end

  Jekyll::Hooks.register :documents, :pre_render, &convert
  Jekyll::Hooks.register :pages, :pre_render, &convert

  Jekyll::Hooks.register :site, :post_write do |_site|
    AmazonCard.missing.each do |url, paths|
      msg = "Amazon カードのキャッシュがない: #{url}（#{paths.uniq.join(', ')}）。`ruby bin/amazon_cache.rb` を実行して commit してください"
      Jekyll.logger.warn 'AmazonCard:', msg
      puts "::warning file=#{paths.first}::#{msg}" if ENV['GITHUB_ACTIONS']
    end
  end
end
