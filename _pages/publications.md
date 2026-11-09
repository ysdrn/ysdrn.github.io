---
layout: page
permalink: /publications/
title: publications
og_title: publications of Ren Yoshida
description: 吉田廉の論文・翻訳・書評・対談などの一覧。
nav: true
nav_order: 2
---

{% include bib_search.liquid %}

<div class="publications">

{% comment %}
  papers.bib is shared with /talks/. Talks (incl. comments) are @inproceedings and
  live on that page; everything else is a publication. Add new entry types here if used.
{% endcomment %}
{% bibliography --query @article,@book,@incollection,@inbook,@misc,@mastersthesis,@phdthesis,@unpublished %}

</div>
