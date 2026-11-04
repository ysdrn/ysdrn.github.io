#!/usr/bin/env ruby
# frozen_string_literal: true
Encoding.default_external = Encoding::UTF_8

# Amazon カード用キャッシュ（_data/amazon_cache.json）を作る・点検する
#
#   ruby bin/amazon_cache.rb              # 本文中の Amazon URL のうち未キャッシュのものだけ取得
#   ruby bin/amazon_cache.rb --check      # 取得せず、未キャッシュの URL を列挙（あれば exit 1）
#   ruby bin/amazon_cache.rb --check --warn   # 同上だが exit 0（CI 用。GitHub Actions では ::warning:: を出す）
#   ruby bin/amazon_cache.rb --refresh B0XXXXXXXX   # 指定 ASIN を再取得
#   ruby bin/amazon_cache.rb --refresh-all          # 全件再取得（画像 URL が死んだとき）
#
# 自分の Mac（住宅用 IP、ブラウザと同じ UA）から Amazon の商品ページを 1 回だけ読み、
# 商品名・著者・画像 URL（m.media-amazon.com への直リンク）を保存する。
# GitHub Actions からは Amazon が bot 対策で 503 や CAPTCHA を返すので、ビルド時には取得しない。
# bot 対策ページを掴んだときは何も保存しない（壊れたデータでキャッシュを汚さない）。
# 価格は保存も表示もしない（アソシエイト参加要件 2(b)）。

require 'json'
require 'cgi'
require 'optparse'
require 'open3'
require_relative '../_plugins/amazon_card'

ROOT = File.expand_path('..', __dir__)
SCAN_GLOBS = %w[_diary/**/*.md _posts/**/*.md _pages/**/*.md _news/**/*.md].freeze
UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36'
SLEEP_BETWEEN_FETCHES = 1.5

opts = { check: false, warn: false, refresh: [], refresh_all: false, quiet: false }
OptionParser.new do |o|
  o.on('--check') { opts[:check] = true }
  o.on('--warn') { opts[:warn] = true }
  o.on('--refresh ASIN') { |a| opts[:refresh] << a.upcase }
  o.on('--refresh-all') { opts[:refresh_all] = true }
  o.on('--quiet') { opts[:quiet] = true }
end.parse!

def log(msg, opts)
  warn msg unless opts[:quiet]
end

# Ruby の Net::HTTP は TLS 指紋で Amazon に弾かれる（bot 対策ページが返る）。
# curl は同じ Mac から通るので、取得は curl に任せる
def curl(*args)
  out, err, st = Open3.capture3('curl', '-s', '--max-time', '30', '-A', UA, '-H', 'Accept-Language: ja-JP,ja;q=0.9', *args)
  raise "curl 失敗: #{err.strip}" unless st.success?
  out.force_encoding('UTF-8')
end

# 短縮 URL → 商品ページ URL（1 ホップずつ追う）
def resolve(url)
  current = url
  5.times do
    break if current =~ /amazon\.co\.jp/
    nxt = curl('-o', '/dev/null', '-w', '%{redirect_url}', current).strip
    break if nxt.empty? || nxt == current
    current = nxt
  end
  current
end

def fetch_page(url)
  body = curl('-L', '-w', '\n%{http_code} %{url_effective}', url)
  body, status_line = body.rpartition("\n").values_at(0, 2)
  code, final_url = status_line.split(' ', 2)
  raise "HTTP #{code}" unless code == '200'
  [final_url, body]
end

def blocked?(body)
  body.include?('api-services-support@amazon.com') ||
    body =~ /<title>[^<]*(Robot Check|Bot Check|CAPTCHA)[^<]*<\/title>/i ||
    body =~ /id="captchacharacters"/
end

def parse_product(body)
  item = {}
  if (t = body[/id="productTitle"[^>]*>\s*([^<]+?)\s*</m, 1])
    item['title'] = CGI.unescapeHTML(t).gsub(/\s+/, ' ').strip
  end

  if (byline = body[/<div id="bylineInfo"[^>]*>.*?<\/div>/m])
    names = byline.scan(/<span class="author[^"]*"[^>]*>.*?<a[^>]*>\s*([^<]+?)\s*<\/a>.*?<\/span>\s*<\/span>/m).flatten
    names = byline.scan(/<a class="a-link-normal[^"]*"[^>]*>\s*([^<]+?)\s*<\/a>/).flatten if names.empty?
    names = names.map { |n| CGI.unescapeHTML(n).gsub(/\s+/, ' ').strip }.reject(&:empty?).uniq
    item['author'] = names.join('、') unless names.empty?
  end

  image = body[/"hiRes":"(https:\/\/m\.media-amazon\.com\/images\/I\/[^"]+)"/, 1] ||
          body[/id="landingImage"[^>]*data-old-hires="(https:\/\/m\.media-amazon\.com\/images\/I\/[^"]+)"/, 1] ||
          body[/"large":"(https:\/\/m\.media-amazon\.com\/images\/I\/[^"]+)"/, 1] ||
          body[/property="og:image"\s+content="(https:\/\/m\.media-amazon\.com\/images\/I\/[^"]+)"/, 1]
  if image
    # サイズ指定子を揃える: .../I/<id>._SL1459_.jpg → .../I/<id>._SL500_.jpg
    image = image.sub(/\._[A-Z0-9_,]+_\.(jpe?g|png)\z/i, '.\1').sub(/\.(jpe?g|png)\z/i, '._SL500_.\1')
    item['image'] = image
  end
  item
end

def collect_urls
  urls = []
  SCAN_GLOBS.each do |g|
    Dir.glob(File.join(ROOT, g)).sort.each do |path|
      File.read(path, encoding: "UTF-8").scan(AmazonCard::AMAZON_URL_RE) { urls << [$1, path.sub("#{ROOT}/", '')] }
    end
  end
  urls
end

cache = AmazonCard.load_cache(ROOT)
urls = collect_urls

# --check: 取得せず点検だけ
if opts[:check]
  missing = urls.reject { |url, _| asin, item = AmazonCard.lookup(url, cache); asin && item }
  missing.each do |url, path|
    msg = "Amazon カードのキャッシュがない: #{url}（#{path}）。`ruby bin/amazon_cache.rb` を実行して commit してください"
    warn msg
    puts "::warning file=#{path}::#{msg}" if ENV['GITHUB_ACTIONS']
  end
  log("#{urls.size} 件中 #{missing.size} 件が未キャッシュ", opts)
  exit(missing.empty? || opts[:warn] ? 0 : 1)
end

changed = false
failed = []
fetched_asins = {}

urls.map(&:first).uniq.each do |url|
  asin, item = AmazonCard.lookup(url, cache)
  need = item.nil? || opts[:refresh_all] || (asin && opts[:refresh].include?(asin))
  next unless need

  begin
    product_url = url
    if AmazonCard.short_url?(url)
      product_url = resolve(url)
      asin ||= AmazonCard.extract_asin(product_url)
      raise "短縮 URL から ASIN を取れない（#{product_url}）" unless asin
      cache['links'][url] = asin
      changed = true
    end
    asin ||= AmazonCard.extract_asin(product_url)
    raise 'ASIN を取れない' unless asin

    if fetched_asins[asin] || (cache['items'][asin] && !opts[:refresh_all] && !opts[:refresh].include?(asin))
      next # 同じ商品の別リンク
    end

    sleep SLEEP_BETWEEN_FETCHES unless fetched_asins.empty?
    final_url, body = fetch_page("https://www.amazon.co.jp/dp/#{asin}")
    raise 'bot 対策ページ（CAPTCHA）を返された。時間をおいて再実行' if blocked?(body)

    parsed = parse_product(body)
    raise '商品名が取れない（ページ構造が変わった？）' unless parsed['title']

    parsed['image'] ||= format(AmazonCard::LEGACY_IMAGE, asin) if AmazonCard.isbn10?(asin)
    cache['items'][asin] = { 'asin' => asin, 'url' => final_url.sub(/\?.*/, '') }.merge(parsed).merge('fetched_at' => Time.now.strftime('%Y-%m-%d'))
    fetched_asins[asin] = true
    changed = true
    log("取得: #{asin} #{parsed['title']}#{parsed['image'] ? '' : '（画像なし）'}", opts)
  rescue StandardError => e
    failed << [url, e.message]
    log("失敗: #{url}: #{e.message}", opts)
  end
end

if changed
  AmazonCard.save_cache(ROOT, cache)
  log("#{AmazonCard::CACHE_FILE} を更新（#{fetched_asins.size} 件取得）", opts)
else
  log('更新なし', opts)
end

unless failed.empty?
  warn "#{failed.size} 件取得できなかった。ビルドは簡易カードで通るので、あとで再実行してください"
end
