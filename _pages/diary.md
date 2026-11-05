---
layout: page
permalink: /diary/
title: diary
og_title: diary of Ren Yoshida
description:
nav: true
nav_order: 5
robots: noindex, nofollow, noarchive, nosnippet, noimageindex
---

{% comment %}シリーズの入口。_data/diary_series.yml にあって週が一つ以上あるものだけ出す{% endcomment %}
{% assign series_links = "" | split: "" %}
{% for s in site.data.diary_series %}
  {% assign in_series = site.diary | where: "series", s.key | sort: "date" %}
  {% if in_series.size > 0 %}
    {% assign first = in_series | first %}
    {% capture link %}<a href="{{ '/diary/' | append: s.key | append: '/' | relative_url }}">{{ s.name }}</a><small class="text-muted">（{{ first.date | date: "%Y年%-m月" }}〜）</small>{% endcapture %}
    {% assign series_links = series_links | push: link %}
  {% endif %}
{% endfor %}
{% if series_links.size > 0 %}
<p class="diary-series-list">シリーズ: {{ series_links | join: " / " }}</p>
{% endif %}

{% include diary_list.liquid %}
