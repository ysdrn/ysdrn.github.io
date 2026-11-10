---
layout: notes_index
permalink: /blog/
title: notes
og_title: notes of Ren Yoshida
nav: true
nav_order: 4
---

  <ul class="post-list notes-list">

    {%- comment -%} ページ送りはしない（全件を一枚に。左のタグナビの絞り込みは一覧の中だけで効くので）。レイアウトは _layouts/notes_index.liquid {%- endcomment -%}
    {% for post in site.posts %}

    {%- comment -%}
    2026-11-10 diary の一覧（_includes/diary_list.liquid）と同じ形にした: 題 / description（なければ本文の冒頭 90 字） / メタ行「2022年4月24日」。front matter に cover（写真）がある記事は右にサムネ（題入りのカード画像）。
    テーマの「1 min read · April 24, 2022」と年だけの行は出さない。タグ・カテゴリがあればメタ行に続けて出す。
    {%- endcomment -%}
    {% if post.description and post.description != "" %}
      {% assign blurb = post.description %}
    {% else %}
      {% assign blurb = post.content | strip_html | strip_newlines | strip | truncate: 90 %}
    {% endif %}

    <li data-tags="{% for tag in post.tags %}{{ tag | slugify }}{% unless forloop.last %},{% endunless %}{% endfor %}">

      {%- comment -%} 題とサムネを横に並べ、紹介文と日付の行はその下に全幅で出す（スマホでも文字の列が細くならないように） {%- endcomment -%}
      <div class="notes-item">
        <h3>
        {% if post.redirect == blank %}
          <a class="post-title" href="{{ post.url | relative_url }}">{{ post.title }}</a>
        {% elsif post.redirect contains '://' %}
          <a class="post-title" href="{{ post.redirect }}" target="_blank">{{ post.title }}</a>
        {% else %}
          <a class="post-title" href="{{ post.redirect | relative_url }}">{{ post.title }}</a>
        {% endif %}
      </h3>
      {%- comment -%} サムネは題を重ねたカード画像（bin/note_cards.py が作る）。リンクは題と同じ先なので読み上げ・Tab からは外す {%- endcomment -%}
      {% if post.cover %}
        <a class="notes-item-cover" href="{{ post.url | relative_url }}" tabindex="-1" aria-hidden="true"><img src="{{ post.cover | prepend: '/assets/img/notes/card/' | relative_url }}" width="1280" height="670" alt="" loading="lazy"></a>
      {% endif %}
      </div>
      {% if blurb != "" %}<p>{{ blurb }}</p>{% endif %}
      <p class="post-meta">
        {{- post.date | date: "%Y年%-m月%-d日" -}}
        {%- for tag in post.tags %} &nbsp; &middot; &nbsp; <a href="{{ tag | slugify | prepend: '/blog/#tag=' | relative_url }}">#{{ tag }}</a>{% endfor -%}
        {%- for category in post.categories %} &nbsp; &middot; &nbsp; <a href="{{ category | slugify | prepend: '/blog/category/' | relative_url }}">{{ category }}</a>{% endfor -%}
      </p>
    </li>

    {% endfor %}

  </ul>

