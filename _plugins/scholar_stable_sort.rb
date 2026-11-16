# frozen_string_literal: true

# publications / talks を年月の新しい順に並べ、同じ年月の項目は papers.bib に書いた順のままにする。
#
# _config.yml の scholar で sort_by: year,month / order: descending,descending を指定している。
# jekyll-scholar の sort は Array#sort（安定でない）なので、同じ年月の項目（同じ号の翻訳と訳者解説など）の
# 順番がビルドごとに入れ替わりうる。比べ方は元の sort と同じで、差がないときだけ bib の順で決める。
# （2026-11-16、それまでは年だけで並べていたので、同じ年の中が bib の順になっていた）

require 'jekyll/scholar'

module Jekyll
  class Scholar
    module Utilities
      def sort(unsorted)
        return unsorted if skip_sort?

        unsorted.each_with_index.sort do |(e1, i1), (e2, i2)|
          c = sort_keys.map.with_index do |key, idx|
            v1 = resolve_sort_value(e1, key)
            v2 = resolve_sort_value(e2, key)
            (sort_order[idx] || sort_order.last) =~ /^(desc|reverse)/i ? v2 <=> v1 : v1 <=> v2
          end.find { |x| x != 0 } || 0
          c.zero? ? i1 <=> i2 : c
        end.map(&:first)
      end
    end
  end
end
