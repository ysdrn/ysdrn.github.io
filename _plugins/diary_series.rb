# frozen_string_literal: true

# 日記のシリーズごとの一覧ページ /diary/<key>/ を _data/diary_series.yml から作る。
# 週ファイルの front matter `series: <key>` で所属を決める（表示は _includes/diary_list.liquid）。
# /diary/ 本体と同じく検索エンジンには出さない（robots noindex、sitemap 外）。

module Jekyll
  class DiarySeriesPageGenerator < Generator
    safe true
    priority :low

    def generate(site)
      series = site.data['diary_series']
      return unless series.is_a?(Array)

      series.each do |s|
        key = s['key'].to_s
        next if key.empty?

        page = PageWithoutAFile.new(site, site.source, File.join('diary', key), 'index.html')
        page.data['layout'] = 'page'
        page.data['title'] = s['name']
        page.data['description'] = s['description']
        page.data['og_title'] = "#{s['name']} | diary of Ren Yoshida"
        page.data['permalink'] = "/diary/#{key}/"
        page.data['series_key'] = key
        page.data['robots'] = 'noindex, nofollow, noarchive, nosnippet, noimageindex'
        page.data['sitemap'] = false
        page.data['toc'] = { 'sidebar' => 'left' } # CV と同じ左の目次（年・月）
        page.content = "{% include diary_list.liquid series=\"#{key}\" %}"
        site.pages << page
      end
    end
  end
end
