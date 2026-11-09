---
layout: page
permalink: /talks/
title: talks
og_title: talks of Ren Yoshida
description: 吉田廉の学会・研究会での発表とコメントの一覧。
nav: true
nav_order: 3
---

{% include bib_search.liquid %}

<div class="publications">

{% comment %}
  Talks, comments and other spoken contributions: every @inproceedings entry in papers.bib.
  abbr distinguishes own presentations (発表) from commentator roles (コメンテーター).
{% endcomment %}
{% bibliography --query @inproceedings %}

</div>
