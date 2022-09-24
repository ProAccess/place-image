---
title: "Reimagining Legislation for Community Associations"
graphics: yes
papersize: "Letter"
imageplacement: cap_position=above, width=50%, cap_h_position=center, cap_text_align=center, cap_text_size=small, html:cap_width=75%, cap_width=80%, position=float-left, html:v_padding=.1in, h_padding=.15in, cap_text_style="plain", cap_label_style=bold, v_padding=.1in, cap_label_sep=":\_", cap_label=Figure
geometry: "left=1in, right=1in, top=.75in, bottom=.75in, footskip=1cm"
output:
  pdf_document:
    pandoc_args: ["--lua-filter=place-image.lua"]
    toc: true
    toc_depth: '3'
    keep_tex: true
    keep_md: true
    template: "templates/eisvogel.latex"
  latex_document:
    pandoc_args: ["--lua-filter=place-image.lua"]
    toc: true
    toc_depth: '3'
    keep_md: true
    template: "templates/eisvogel.latex"
  html_document:
    pandoc_args: ["--lua-filter=place-image.lua"]
    toc: true
    toc_depth: '3'
    lof: true
    css: "css-md/mdstyles.css"
    self_contained: no
    df_print: paged
    keep_md: true
    template: "templates/default.html5"
  epub_document:
    pandoc_args: ["--lua-filter=place-image.lua"]
    toc: true
    toc_depth: '3'
    keep_md: true
    css: "css-md/epub.css"
    template: "templates/default.epub3"
  word_document:
    pandoc_args: ["--lua-filter=place-image.lua"]
    reference_docx: "templates/reference_template.docx"
    toc: true
    toc_depth: 3
    keep_md: true
params:
  author: George Markle
---

<!-- Include this for any .Rmd file to enable graphic positioning
This library was developed experimentally to provide a R-Studio function for placing images within R documents. It works well for html but for MS Word it relies completely upon Word's custom paragraph and character styles and requires a large library of styles to be included within the Word template used for docx generation.

This was superseded by a new lua filter that accepts the default markdown image notation, along with additional attributes, and generates html-native and Word-native code for direct inclusion in final documennts.
-->
# Costly consequences of underinformed directors

![This is a caption with my figure. It has all of the absolutely glorious attributes one could wish for.\label{mylabel1}](./images-md/availability-curve-500.png){ position="float-right" cap_position="above" cap_width=90% cap_h_position=center v_padding=.15in cap_label_style=bold-italic pdf_adjust_lines="15"}

How many corporations exist with directors responsible for protecting a
large portion of [stakeholders' equity](#mylabel2) typically having so little
applicable experience or knowledge of their duties or legal
responsibilities?

We have all seen and read about [consequences](#mylabel2) of failed governance of
community associations --- from petty irritations of hapless
administration of architectural rules preventing a homeowner from flying
a flag, to devastation of a community and lost lives resulting from
failure to conduct structural inspections and maintain adequate
reserves.

HOA managers and attorneys too often witness the dearth of volunteers
and the inordinate costs in time and funds wasted by HOA Boards
attempting to navigate issues affected by laws and best practices about
which directors are unaware --- and time and costs for recovering from
consequences of actions or inaction.

## Pool of qualified candidates varies with community size

![This is another caption with my figure. It has all of the absolutely glorious attributes one could wish for.](./images-md/cert-1000.png){width=50% latex:width=45% docx:width=40% position="float-left" cap_position="below" cap_width=95% cap_h_position=center cap_label_style=plain v_padding=.1in cap_label="Figure" pdf_adjust_lines="11"}

Populations of most towns and cities usually are sufficient to enable
competitive elections and town- and city-councils with talents in
disciplines applicable to operating their governments. 

However, the comparatively small population of most homeowners associations often
means a dearth of board candidates, many without applicable
qualifications. Often, HOA boards find themselves with directors with
virtually *no experience* in business, finance, insurance, law,
construction or many other applicable fields.

## HOAs with underqualified directors are the rule --- not the exception

HOA boards with under-qualified directors can have profound, negative
and costly effects on the lives of their members.

In my over forty-years of experience with HOAs I've found well-meaning&nbsp;  [volunteers](#mylabel1) in a neighborhood setting tend to conduct meetings within a
social context wherein decisions are heavily influenced by uninformed
sensibilities and impulses of neighbors present, without due diligence
and investigation, consideration of state regulation or standards of
governance intended to protect broader interests.

![This is a test caption to test display of a longer caption. This is a test caption to test display of a longer caption.\label{mylabel2}](./images-md/makemyhoaok logo.png){position=center width=40% cap_text_align=center cap_text_size=small cap_text_style=plain cap_width=70% cap_position=below cap_h_position=center cap_label="Figure"}
