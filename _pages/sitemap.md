---
layout: page
permalink: /sitemap/
title: sitemap
description:
nav: false
---

{%- comment -%}
サイトマップ（2026-11-10）。ページの一覧と Amazon アソシエイトの表記を置く。全ページのフッターからリンクする（_includes/footer.liquid）。
- 一覧はナビに出るページ（nav: true、nav_order 順）の前に about（/）を置き、notes の下に記事を新しい順に並べる。diary の各週は並べない（一覧へのリンクだけ）
- アソシエイトの表記は運営規約 第5条「乙がアソシエイトであることの表示」の文言どおり。名称はサイト名 yoshidaren
- 機械向けの sitemap.xml は jekyll-sitemap が別に作る（このページとは無関係）
{%- endcomment -%}
{% assign nav_pages = site.pages | where: "nav", true | sort: "nav_order" %}
{% assign about_page = site.pages | where: "permalink", "/" | first %}

<ul class="sitemap-list">
  <li><a href="{{ '/' | relative_url }}">{{ about_page.title }}</a></li>
  {% for p in nav_pages %}
    <li>
      <a href="{{ p.url | relative_url }}">{{ p.title }}</a>
      {% if p.permalink == '/blog/' and site.posts.size > 0 %}
        <ul>
          {% for post in site.posts %}
            <li><a href="{{ post.url | relative_url }}">{{ post.title }}</a> <span class="sitemap-date">{{ post.date | date: '%Y年%-m月%-d日' }}</span></li>
          {% endfor %}
        </ul>
      {% endif %}
    </li>
  {% endfor %}
</ul>

<p class="sitemap-associate">Amazonのアソシエイトとして、{{ site.title }}は適格販売により収入を得ています。</p>
