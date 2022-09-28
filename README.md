# A solution for enhanced image control

The *image-placement.lua* Pandoc filter is intended to address some commonly encountered shortcomings when displaying images in documents created by Pandoc from markdown documents. Now you can specify a variety of image parameters directly within markdown images statements. Here are two brief examples:

![](./images-md/examples.png)

This filter allows you to specify parameters such as...

- "width" -- Image width

- "position" -- horizontal position on page (left, center, right, float-left, float-right)
- "h_padding", "v_padding" -- padding between image, caption and surrounding text.
- "cap_width" -- Width of caption text. If expressed as percent, will be relative to image width.
- "cap_position" -- above or below. Default is above.
- "cap_h_position" -- horizontal position of caption block relative to image (left, center, right). Default is center.
- "cap_text_align" -- If specified: left, center, right
- "cap_text_size" -- If specified: small, normal, large. Default is normal.
- "cap_text_font" -- If specified, font must be among system fonts.
- "cap_text_style" -- If specified: plain, italic, bold, bold-oblique, bold-italic. Default is plain.
- "cap_label" -- If specified, can be any, e.g., "Figure", "Photo", "My Fantastic Table", etc. Number following label will be respective to the label.
- "cap_label_style" -- If specified: plain, italic, bold, bold-oblique, bold-italic. Default is plain.
- "cap_label_sep" -- If specified, indicates separater between caption label number and caption, e.g., ":&nbsp;"
- "pdf_adjust_lines" -- Used to compensate for inaccurate wraps in Pandoc conversions to pdf and latex formats. 

This filter lets you specify display of images in two ways: (1) for each image and (2) for all images, globally.

### You can specify params for each specific image

Each markdown image statement can include desired parameters. For example, you can specify an image width, its caption label and caption position like this:

`!\[My caption](my-image.jpg){width=2.5in cap_label="My Figure" cap_position=above}`

A parameter for a specific image will override any global parameter.

### ... or globally, for *all* images

You can affect all images within a global "[imageplacement](#global_params)" statement in the YAML Meta section at the top of the markdown document, e.g.,

`imageplacement: width=2.5in, cap_label="My Figure", cap_position=above`

## Parameters for a specific image
  
Parameters in *specific image* statements must *not* be separated by commas; doing so will cause Pandoc to throw up in its mouth, with unexpected results. (This contrasts with how global parameters must be separated *with* commas within the YAML Meta statement. I know, I know — but that's out of my control.)

The following illustrates how to easily size a specific image to 45% of page width, float it to the right with text wrapped around it, and place the caption *below* (rather than above) the image.

`![My caption](my-image.jpg){width=45% position=float-right cap_position=below}`

These and other available parameters are [listed below][#commands_table].

## Global parameters applying to *all* doc images <a name="global_params"></a>

Note, global parameters must be separated *with* commas within the global YAML Meta imageplacement statement at the top of the markdown document, for example,

`imageplacement: cap_label="Figure", cap_label_sep=":_"`

Global parameter(s) apply to *all* images or any parameter not otherwise specified in a specific image statement. For example, you may wish to include a standard label for all images, such as  "My Figure 1: " to precede each image caption. You can accomplish this with this 'imageplacement' statement in your YAML header:

<pre><code>---
title: "Plan for Controlling Weather"
<span style="color:blue">imageplacement: cap_label="My Figure", cap_label_sep=":_"</span>
output:
  html_document:
    pandoc_args: ["--lua-filter=place-image.lua"]
    css: "css-md/mdstyles.css"
    template: "templates/default.html5"
params:
  author: Your Name
---
</code></pre>

This will cause every image to be preceded by the label "My Figure" followed by a space and sequence number particular to the label. The parameter line

`cap_label_sep=":_" `

will cause a colon and space to separate that from the caption, as in "My Figure 3: This is my caption..." 

You can cause the label to be bold face by adding the "cap_label_style" parameter, for example,

`imageplacement: cap_label="My Figure", cap_label_sep=":_", cap_label_style=bold`

This would produce a caption like this: "**My Figure 3:** This is my caption..."

> Note 1 — unlike with parameters listed with images, image parameters in the YAML header must be separated by commas, due to the way the Lua language scans the YAML header for parameters; failing to include commas may cause Pandoc to pee on itself, causing a "scan" error and high blood pressure.

> Note 2 — Note the "cap_label_sep" parameter of ":\_". The underscore character following the colon indicates a space "&nbsp;" character. This is because an actual space character in a YAML parameter string also can cause a "scan" error. Therefore, use the "_" underscore character to indicate a space.

# Document formats supported

Currently this filter supports Pandoc converson of markdown documents to

- html
- docx
- pdf — The '[wrapfig](https://www.ctan.org/pkg/wrapfig?lang=en)' package is required for text-wrap. See [Using wrapfig](#using-wrapfig), below.
- latex — The '[wrapfig](https://www.ctan.org/pkg/wrapfig?lang=en)' package is required for text-wrap. See [Using wrapfig](#using-wrapfig), below.
- epub

# What this filter allows you to do{#commands_table}

Below is a table of parameters you can include in your markdown image specifier. Wherever a size dimension is required, you can use any of the following dimensions. (Ensure there are no spaces between the number and dimension, e.g., "350px". "350 px" may produce unexpected results.

- % — percentage of parent width
- in — inches
- cm — centimeters
- mm — milimeters
- px — pixels (at 72 per-inch)

You may enter parameters in any order, for example:

`![My caption](my-image.jpg){position=float-left cap_position=below width=50%}`
&nbsp;

## Parameters you can use 

| Parameter                 | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                | Default               | Examples                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| :------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| width                     | Image width                                                                                                                                                                                                                                                                                                                                                                                                                          | 50%                   | width=35%, width=200px, width=3cm, width=2.5in                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| position                  | Horizontal position relative to page                                                                                                                                                                                                                                                                                                                                                                                                 | center                | Options: left, center, right, float-left, float-right<br/>Examples: position=center, position=float-right                                                                                                                                                                                                                                                                                                                                                                             |
| h_padding                 | Horizontal separation between image and surrounding text                                                                                                                                                                                                                                                                                                                                                                             | 0.15in                | h_padding=0.15in, h_padding=4mm, h_padding=10px, etc.                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| v_padding                 | Vertical separation between image and surrounding text                                                                                                                                                                                                                                                                                                                                                                               | 0.1in                 | v_padding=0.12in, v_padding=.3cm, v_padding=9px, etc.                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| cap_width                 | Width of caption. If percent, relative to image width                                                                                                                                                                                                                                                                                                                                                                                | 90%                   | cap_width=100%, cap_width=250px, cap_width=1in, etc.                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| cap_position              | Caption vertical position relative to image                                                                                                                                                                                                                                                                                                                                                                                          | above                 | Options: above, below<br/>Example: cap_position=below                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| cap_h_position            | Caption horizontal alignment relative to image (caption itself may only be above or below)                                                                                                                                                                                                                                                                                                                                           | center                | Options: left, center, right<br/>Example: cap_h_position=left                                                                                                                                                                                                                                                                                                                                                                                                                         |
| cap_text_align            | Caption text alignment                                                                                                                                                                                                                                                                                                                                                                                                               | center                | Options: left, center, right<br/>Example: cap_text_align=left                                                                                                                                                                                                                                                                                                                                                                                                                         |
| cap_text_size             | Allows tweak of caption text size relative to body text                                                                                                                                                                                                                                                                                                                                                                              | small                 | Options: small, normal, large<br/>Example: cap_text_size=normal                                                                                                                                                                                                                                                                                                                                                                                                                       |
| cap_text_font             | If specified, font must be a registered system font; use sparingly                                                                                                                                                                                                                                                                                                                                                                   |                       | Options may include any system font.<br/>Examples: cap_text_font=Helvetica, cap_text_font=Arial, cap_text_font=Times, etc.                                                                                                                                                                                                                                                                                                                                                            |
| cap_text_style            | Caption text style                                                                                                                                                                                                                                                                                                                                                                                                                   | plain                 | plain, italic, bold, oblique, bold-oblique                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| cap_label                 | Allows specifying a numbered custom label that appears before caption                                                                                                                                                                                                                                                                                                                                                                | none                  | Options may include any string. For example, "cap_label=Figure" will result in a label like "Figure 4".<br/>cap_label=Photo will produce a lable like "Photo 1", etc. Note: If your label is more than one word, you must enclose it within quotes, e.g., "My Photo".                                                                                                                                                                                                                 |
| cap_label_sep&nbsp;&nbsp; | Allows specifying a custom separator character(s) between the numbered custom label and caption. Note: If your label is more than one word, you must enclose it within quotes, e.g., "My Photo"; otherwise, only the first word ("My") will be included.                                                                                                                                                                             | &nbsp;&nbsp;":&nbsp;" | By default, label and caption are separated by a colon followed by a space character, like this: <br/>"Figure 4: My caption..."<br/>Ensure you enclose your custom separater within quotes if it will contain any space character and use the underscore character to indicate the space. For example, the following shows a custom separator, a hyphen surrounded by space characters:<br/>'cap_label_sep="\_-\_"'<br/>It will appear as, for example,<br/>"Photo 2 - My caption..." |
| latex_adjust_lines        | This allows tweaking the wrap height for a wrapped image in latex/pdf formats. Sometimes the wrapfig extension misjudges wrap height and text may flow into the image below or have too much empty space below. Should this occur, you may try specifying different equialent line heights for that image, e.g., "10", "15", etc. (You also may wish to tweak the image width in such cases, e.g., "width=42%" instead of "...45%.") |                       | This parameter affects *only* latex/pdf images. Examples: latex_adjust_lines=10, latex_adjust_lines=12, latex_adjust_lines=15, etc.                                                                                                                                                                                                                                                                                                                                                   |
|                           |
* A number followed immediately by one of "in", "cm", "mm" or "px"

# Invoking filter from Pandoc

This filter can be invoked on the command line with the "--lua-filter" option, e.g., "\-\-lua-filter=place-image.lua". An example might be

`pandoc -f markdown -t html test.md -o test.html --css=./css-md/mdstyles.css --template=templates/default.html5 --lua-filter=./place-image.lua -s`

Alternatively, if you are working within an environment like R-Studio that runs Pandoc, it may be included in the YAML header, for example,

<pre><code>---
title: \"My extraordinarily beautiful document\" 
output:
  html_document:
<span style="color:blue">    pandoc_args: [\"--lua-filter=place-image.lua\"]</span>
---
</code></pre>

# Special considerations for latex/pdf documents

## Include these packages

For Pandoc conversion into Latex and pdf, these three package statements should be included in the latex template file. (They already are in the "default.latex" and "eisvogel.latex" templates in the "templates" folder on this site.)

`\usepackage{layouts} % allows calculating width relative to latex/pdf page width
\usepackage{wrapfig} % enables text wrap-around of figures
\usepackage[export]{adjustbox}  % must include to enable additional positioning`

Again, these package statements already are in following two template versions included on this site, either of which you can use for Pandoc conversion into latex/pdf documents:

- default.latex — The default latex template by Pandoc author John MacFarlane, to which I added those statements.
- eisvogel.latex - The latex template by Pascal Wagler, based upon template by Pandoc author John MacFarlane. This is the latex template I prefer for its expanded capabilities.

## Image wrapping in latex/pdf documents

Image wrapping for floating images in these formats is handled by Donald Arseneau's neat 'wrapfig' package{#using-wrapfig}.

### Repairing defective text-wraps

There is a known issue with respect to wrapfig's text-wrap accuracy. After you've generated a latex or pdf document, it's common to find some floated images extending into wrapped text below, or with extra blank space below the image. This is because wrapfig *guesses* the equivalent number of blank lines needed to match the height of the image — and sometimes it guesses wrong. Should this problem occur, you may enter a 'pdf_adjust_lines' parameter to try different equialent line heights for that image, e.g., "10", "15", etc., until you are satisfied. Here are a few examples of using the 'pdf_adjust_lines' parameter:

`pdf_adjust_lines=10
pdf_adjust_lines=12
pdf_adjust_lines=15, etc.`
  
# Different parameters for different document formats

This filter allows you to specify different image parameters, depending upon document format. For example, you may wish images in your Word .docx files to be slightly smaller than those in your .html documents. You can preface any parameter with its format identifier and that parameter will override any default or other image parameter.

For example, the following will cause the image width to appear at 50% of page width for any supported format except .docx images, which will be sized to 45%:

`![My caption](my-image.jpg){position=float-right width=50% docx:width=45%}]`

Supported document format identifiers include the following:

- html:
- docx:
- pdf:
- latex:
- epub:

I hope you find some of this useful. I welcome any corrections, feedback and suggestions!

George
