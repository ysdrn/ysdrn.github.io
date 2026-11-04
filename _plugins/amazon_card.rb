require 'net/http'
require 'uri'
require 'json'
require 'cgi'
require 'fileutils'

module AmazonCard
  AMAZON_URL_RE = %r{^(https?://(?:www\.)?amazon\.co\.jp/[^\s]+|https?://amzn\.(?:to|asia)/[^\s]+|https?://link\.amazon(?:\.co\.jp)?/[^\s]+)$}

  CACHE_FILE = '_data/amazon_cache.json'

  class << self
    def load_cache(site)
      path = File.join(site.source, CACHE_FILE)
      if File.exist?(path)
        JSON.parse(File.read(path))
      else
        {}
      end
    end

    def save_cache(site, cache)
      path = File.join(site.source, CACHE_FILE)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(cache))
    end

    def extract_asin(url)
      return $1 if url =~ %r{/dp/([A-Z0-9]{10})}i
      return $1 if url =~ %r{/gp/product/([A-Z0-9]{10})}i
      return $1 if url =~ %r{/([A-Z0-9]{10})(?:[/?]|$)}i
      nil
    end

    def extract_title_from_url(url)
      if url =~ %r{amazon\.co\.jp/([^/]+)/dp/}
        raw = $1
        decoded = CGI.unescape(raw)
        decoded.gsub('-', ' ').strip
      end
    end

    def resolve_redirect(url, limit = 3)
      return url if limit <= 0
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = 5
      http.read_timeout = 5
      req = Net::HTTP::Head.new(uri)
      req['User-Agent'] = 'Mozilla/5.0'
      resp = http.request(req)
      if resp.is_a?(Net::HTTPRedirection) && resp['location']
        resolve_redirect(resp['location'], limit - 1)
      else
        url
      end
    rescue => e
      Jekyll.logger.warn "AmazonCard:", "Failed to resolve #{url}: #{e.message}"
      url
    end

    def fetch_og_data(url)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = 5
      http.read_timeout = 10
      req = Net::HTTP::Get.new(uri)
      req['User-Agent'] = 'Mozilla/5.0 (compatible; JekyllBot/1.0)'
      req['Accept-Language'] = 'ja'
      resp = http.request(req)
      body = resp.body.force_encoding('UTF-8')

      data = {}
      if body =~ /property="og:title"\s+content="([^"]+)"/
        data['title'] = CGI.unescapeHTML($1)
      end
      if body =~ /property="og:image"\s+content="([^"]+)"/
        data['image'] = $1
      end
      if body =~ /id="priceblock_ourprice"[^>]*>([^<]+)</
        data['price'] = $1.strip
      elsif body =~ /class="a-price-whole"[^>]*>([^<]+)</
        data['price'] = $1.strip.sub(/\.$/, '')
      end
      data
    rescue => e
      Jekyll.logger.warn "AmazonCard:", "Failed to fetch #{url}: #{e.message}"
      {}
    end

    def get_product_data(url, asin, cache)
      return cache[asin] if cache[asin]

      full_url = url
      if url =~ /amzn\.(to|asia)|link\.amazon/
        full_url = resolve_redirect(url)
        new_asin = extract_asin(full_url)
        asin = new_asin if new_asin
        return cache[asin] if cache[asin]
      end

      data = { 'url' => url, 'asin' => asin }

      title = extract_title_from_url(full_url)
      data['title'] = title if title

      og = fetch_og_data(full_url)
      data['title'] = og['title'] if og['title']
      data['image'] = og['image'] if og['image']
      data['price'] = og['price'] if og['price']

      data['image'] ||= "https://images-fe.ssl-images-amazon.com/images/P/#{asin}.09._SL500_.jpg"
      data['title'] ||= asin

      cache[asin] = data
      data
    end

    def render_card(data)
      url = data['url'] || '#'
      title = CGI.escapeHTML(data['title'] || '')
      image = data['image']
      price = data['price']

      img_html = if image
        %(<a class="amazon-card-image" href="#{url}" rel="noopener nofollow" target="_blank">) +
        %(<span style="background-image:url(#{image})"></span></a>)
      else
        ''
      end

      price_html = if price
        %(<div class="amazon-card-price"><em>#{CGI.escapeHTML(price)}<span class="amazon-card-currency">円</span></em></div>)
      else
        ''
      end

      <<~HTML
        <div class="amazon-card">
          <a class="amazon-card-body" href="#{url}" rel="noopener nofollow" target="_blank">
            <strong class="amazon-card-title">#{title}</strong>
            <span class="amazon-card-domain">amazon.co.jp</span>
            #{price_html}
            <div class="amazon-card-button">
              <span class="amazon-card-button-label">Amazon.co.jpで購入する</span>
            </div>
          </a>
          #{img_html}
        </div>
      HTML
    end

    def process_content(content, cache)
      content.gsub(AMAZON_URL_RE) do |match|
        url = $1.strip
        asin = extract_asin(url)
        unless asin
          if url =~ /amzn\.(to|asia)|link\.amazon/
            resolved = resolve_redirect(url)
            asin = extract_asin(resolved)
          end
        end
        if asin
          data = get_product_data(url, asin, cache)
          render_card(data)
        else
          match
        end
      end
    end
  end
end

Jekyll::Hooks.register :documents, :pre_render do |doc|
  next unless doc.content =~ AmazonCard::AMAZON_URL_RE

  cache = AmazonCard.load_cache(doc.site)
  original_cache = cache.dup
  doc.content = AmazonCard.process_content(doc.content, cache)
  AmazonCard.save_cache(doc.site, cache) if cache != original_cache
end

Jekyll::Hooks.register :posts, :pre_render do |post|
  next unless post.content =~ AmazonCard::AMAZON_URL_RE

  cache = AmazonCard.load_cache(post.site)
  original_cache = cache.dup
  post.content = AmazonCard.process_content(post.content, cache)
  AmazonCard.save_cache(post.site, cache) if cache != original_cache
end
