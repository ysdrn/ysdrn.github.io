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

<div class="row mt-3">
  <div class="col-sm-3">
    <span class="badge rounded-pill bg-primary">{{ entry_ts | date: "%m/%d" }}</span>
  </div>
  <div class="col-sm-9">
    <a href="{{ entry.url | relative_url }}">{% if entry_start_m == entry_end_m %}{{ entry_ts | date: "%m/%d" }}–{{ entry_end_ts | date: "%d" }}{% else %}{{ entry_ts | date: "%m/%d" }}–{{ entry_end_ts | date: "%m/%d" }}{% endif %}</a>
    {% if entry.description %}<br><small class="text-muted">{{ entry.description }}</small>{% endif %}
  </div>
</div>

{% endfor %}

{% if sorted.size == 0 %}
まだ日記はありません。
{% endif %}
