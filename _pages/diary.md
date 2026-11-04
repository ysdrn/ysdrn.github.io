---
layout: page
permalink: /diary/
title: diary
description:
nav: true
nav_order: 4
---

{% assign sorted = site.diary | sort: "date" | reverse %}
{% assign current_year = "" %}
{% for entry in sorted %}
  {% assign entry_year = entry.date | date: "%Y" %}
  {% if entry_year != current_year %}
  {% assign current_year = entry_year %}

## {{ current_year }}

  {% endif %}

  {% assign entry_ts = entry.date | date: "%s" | plus: 0 %}
  {% assign entry_end_ts = entry_ts | plus: 518400 %}
  {% assign entry_start_m = entry_ts | date: "%m" %}
  {% assign entry_end_m = entry_end_ts | date: "%m" %}

{% capture entry_range %}{% if entry_start_m == entry_end_m %}{{ entry_ts | date: "%m/%d" }}–{{ entry_end_ts | date: "%d" }}{% else %}{{ entry_ts | date: "%m/%d" }}–{{ entry_end_ts | date: "%m/%d" }}{% endif %}{% endcapture %}<a href="{{ entry.url | relative_url }}">{{ entry_range }}</a>{% if entry.description %} — {{ entry.description }}{% endif %}

{% endfor %}

{% if sorted.size == 0 %}
まだ日記はありません。
{% endif %}
