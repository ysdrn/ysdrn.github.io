---
layout: page
permalink: /talks/
title: talks
og_title: talks of Ren Yoshida
description:
nav: true
nav_order: 3
---

{% include bib_search.liquid %}

<div class="publications">

{% comment %}
  Talks, comments and other spoken contributions: every @inproceedings entry in papers.bib.
  abbr distinguishes own presentations (Presentation) from commentator roles (Commentator).
{% endcomment %}
{% bibliography --query @inproceedings %}

</div>
