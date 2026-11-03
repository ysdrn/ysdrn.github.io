---
title: Blog
---

# Blog

<ul class="post-list">
{% for post in site.posts %}
  <li>
    <span class="post-date">{{ post.date | date: "%Y年%-m月%-d日" }}</span>
    <div class="post-title"><a href="{{ post.url | relative_url }}">{{ post.title }}</a></div>
    {% if post.excerpt %}<p class="post-excerpt">{{ post.excerpt | strip_html | truncate: 200 }}</p>{% endif %}
  </li>
{% endfor %}
</ul>

{% if site.posts.size == 0 %}
<p class="empty-state">まだ記事はありません。</p>
{% endif %}
