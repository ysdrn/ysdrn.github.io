---
layout: page
permalink: /diary/
title: diary
og_title: diary of Ren Yoshida
description:
nav: true
nav_order: 4
robots: noindex, nofollow, noarchive, nosnippet, noimageindex
---

<style>
.diary-list h2 { margin-top: 2rem; }
.diary-entry { margin-bottom: 0.3rem; }
.diary-week {
  display: inline-block;
  width: 3rem;
  color: var(--global-text-color-light);
  font-size: 0.9em;
}
</style>

<div class="diary-list">
{% assign sorted = site.diary | sort: "date" | reverse %}
{% assign current_year = "" %}
{% for entry in sorted %}
  {% assign entry_year = entry.date | date: "%Y" %}
  {% if entry_year != current_year %}
  {% assign current_year = entry_year %}
  <h2>{{ current_year }}</h2>
  {% endif %}

  {% assign entry_ts = entry.date | date: "%s" | plus: 0 %}
  {% assign entry_end_ts = entry_ts | plus: 518400 %}
  {% assign entry_start_m = entry_ts | date: "%m" %}
  {% assign entry_end_m = entry_end_ts | date: "%m" %}
  {% assign week_num = entry.date | date: "%V" | plus: 0 %}

  <div class="diary-entry">
    <span class="diary-week">w{{ week_num }}</span>
    <a href="{{ entry.url | relative_url }}">{% if entry_start_m == entry_end_m %}{{ entry_ts | date: "%m/%d" }}–{{ entry_end_ts | date: "%d" }}{% else %}{{ entry_ts | date: "%m/%d" }}–{{ entry_end_ts | date: "%m/%d" }}{% endif %}</a>
    {% if entry.description %} <small class="text-muted">— {{ entry.description }}</small>{% endif %}
  </div>
{% endfor %}
</div>

{% if sorted.size == 0 %}
まだ日記はありません。
{% endif %}
