---
layout: page
permalink: /blog/
title: notes
og_title: notes of Ren Yoshida
nav: true
nav_order: 4
pagination:
  enabled: true
  collection: posts
  permalink: /page/:num/
  per_page: 5
  sort_field: date
  sort_reverse: true
  trail:
    before: 1
    after: 3
---

  <ul class="post-list">

    {% if page.pagination.enabled %}
      {% assign postlist = paginator.posts %}
    {% else %}
      {% assign postlist = site.posts %}
    {% endif %}

    {% for post in postlist %}

    {%- comment -%}
    2026-11-10 diary の一覧（_includes/diary_list.liquid）と同じ形にした: 題 / description（なければ本文の冒頭 90 字） / メタ行「2022年4月24日」。
    テーマの「1 min read · April 24, 2022」と年だけの行は出さない。タグ・カテゴリがあればメタ行に続けて出す。
    {%- endcomment -%}
    {% if post.description and post.description != "" %}
      {% assign blurb = post.description %}
    {% else %}
      {% assign blurb = post.content | strip_html | strip_newlines | strip | truncate: 90 %}
    {% endif %}

    <li>

{% if post.thumbnail %}
<div class="row">
          <div class="col-sm-9">
{% endif %}
        <h3>
        {% if post.redirect == blank %}
          <a class="post-title" href="{{ post.url | relative_url }}">{{ post.title }}</a>
        {% elsif post.redirect contains '://' %}
          <a class="post-title" href="{{ post.redirect }}" target="_blank">{{ post.title }}</a>
        {% else %}
          <a class="post-title" href="{{ post.redirect | relative_url }}">{{ post.title }}</a>
        {% endif %}
      </h3>
      {% if blurb != "" %}<p>{{ blurb }}</p>{% endif %}
      <p class="post-meta">
        {{- post.date | date: "%Y年%-m月%-d日" -}}
        {%- for tag in post.tags %} &nbsp; &middot; &nbsp; <a href="{{ tag | slugify | prepend: '/blog/tag/' | relative_url }}">#{{ tag }}</a>{% endfor -%}
        {%- for category in post.categories %} &nbsp; &middot; &nbsp; <a href="{{ category | slugify | prepend: '/blog/category/' | relative_url }}">{{ category }}</a>{% endfor -%}
      </p>

{% if post.thumbnail %}
</div>
  <div class="col-sm-3">
    <img class="card-img" src="{{ post.thumbnail | relative_url }}" style="object-fit: cover; height: 90%" alt="image">
  </div>
</div>
{% endif %}
    </li>

    {% endfor %}

  </ul>

{% if page.pagination.enabled %}
{% include pagination.liquid %}
{% endif %}
