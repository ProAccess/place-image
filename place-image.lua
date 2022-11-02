--[[  --  Copyright 2022 George Markle - 22/11/02
Excellent code to extract image size by MikuAuahDark

place-image.lua – This filter allows greater control over imgage and caption placement and appearance.

]] -- Global variables that must be available for both Meta and Image processing
local image_num = 0 -- Init so can show any error in global Meta statement with 1st image only
local stringify = (require "pandoc.utils").stringify
local err_msg = "" -- Init
local src = "" -- Image path
local geometryVars -- Table from markdown meta table with geometry params
local page_width = 8.5 -- Default printed page width in inches if papersize not specified in markdown header
local l_mar = 1 -- Default Left margin in inches
local r_mar = 1 -- Default Right margin in inches
local pg_text_width = 6.5 -- Default length of text width (page width minus left and right margins); Set default in case page-type not specified
local twips_per_point = 20
local points_per_in = 72
local pixels_per_in = 96
local twips_per_in = points_per_in * twips_per_point
local emu_per_in = 635 * twips_per_in
local cm_per_in = 2.54
local mm_per_in = 25.4
local bookmark = 1 -- Init figure number
local dims = {"%", "in", "inches", "px", "pixels", "cm", "mm"}

local valid_img_attr_names =
    { -- Names of valid parameters. Each parameter and its value separated by "="
        "width", -- Image width
        "columns", -- Divisor by which width will be divided to fit within one of multiple table column cells
        "position", -- horizontal position on page (left, center, right)
        "h_padding", "v_padding", -- padding between image, caption and surrounding text.
        "cap_width", -- Width of caption text. If expressed as percent, will be relative to image width.
        "cap_space", -- Space between caption and image
        "cap_position", -- above or below. Default is above.
        "cap_h_position", -- horizontal position of caption block relative to image (left, center, right). Default is center.
        "cap_text_align", -- If specified: left, center, right
        "cap_text_size", -- If specified: small, normal, large. Default is normal.
        "cap_text_font", -- If specified, font must be among system fonts. Default is body-text.
        "cap_text_style", -- If specified: plain, italic, bold, bold-oblique, bold-italic. Default is plain.
        "cap_label", -- If specified, can be any, e.g., "Figure", "Photo", "My Fantatic Table", etc.
        "cap_label_style", -- If specified: plain, italic, bold, bold-oblique, bold-italic. Default is plain.
        "cap_label_sep", -- If specified, indicates separater between caption label number and caption, e.g., ": "
        "adjust_frame_ht", -- For latex/pdf: - for cases where latex misjudges the equivalent line-height of an image. User may adjust vertical wrap, e.g., 10, 12, 15.
        "close_frame", -- For latex/pdf: Latex may not restore margin below floated image, leaving white space. This will restore margin.
        "keep_with_next", -- For latex/pdf: If header orphaned, move to next page if within x lines of bottom.
        "pdf_anchor_strict", -- Indicates whether image may be moved to nearby location to avoid margin intrusion ()
        "md_cap_ht_adj" -- Adjustment to vertical caption container for markdown documents.
    }
local image_params = {} -- Contains image placement parameters {["param"],{default, global, this}}
local default_i = 1 -- 'Default' column of image params table
local global_i = 2 -- 'Global' column of image params table
local this_i = 3 -- 'This image-specific' column of image params table

local src -- Image source
local img_wd -- Image width from file
local img_ht -- Image height from file
local img_ratio -- Image aspect ratio
local width_entered -- Width as entered
local width_in -- Image width in inches
local columns -- Divisor by which width will be divided to fit within one of multiple table column cells
local wid_frac -- Fraction of page width the image width represents
local wid_percent -- Percentage page width the image width represents (string)
local cap_text -- Caption text
local image_id
local img_label = "" -- From markdown image specification, unique to enable link
local results = "" -- String with code to be returned
local results_img
local docx_cap_pos
local docx_text_align_xml = ""
local docx_wrap = "notBeside"
local docx_padding_h
local docx_padding_v
local docx_cap_space
local frame_position -- Position specified, e.g., left, center, right, float-left, float-right
local frame_pos = "" -- Position abbreviated to left, right, center
local cap_position = ""
local ltx_position = "" -- Latex/PDF image horizontal position and wrap
local ltx_positions = {} -- Contains doc-specifc code for each possible position
local ltx_cap_h_pos -- Latex/PDF caption horizontal position
local ltx_text_align -- Latex/PDF caption text alignment
local ltx_cap_l_wd
local ltx_cap_r_wd
local ltx_cap_h_pos
local adjust_frame_ht -- 'Adjustment' value to shorten latex/pdf image wrap area.
local pdf_anchor_strict -- Indicates strictness of latex image anchor
local pdf_restore_mar -- Indicates altered margin following image should be restored
local keep_with_next -- If fewer than this number of lines left before bottom, move to next page
local cap_docx_ind_l = 0
local cap_docx_ind_r = 0
local cap_html = ""
local gfm_style = ""
local html_style = ""
local cap_text_style = ""
local cap_html_style = ""
local cap_text_html_style = ""
local cap_text_docx_style = ""
local caption_ltx_style = "" -- Style affecting caption paragraph
local cap_text_ltx_style = "X" -- Style affecting characters (italic, bold, font, size)
local cap_text_ltx_align
local cap_label_style = ""
local cap_label_html_style = ""
local cap_label_docx_style = ""
local cap_label_ltx_style = "X"

-- Figure label type allows defining numbered figures with custom labels
local cap_labels = {} -- Figure labels with last sequence number
local cap_label -- Current figure label
local cap_lbl -- Composed label text
local cap_label_sep = "" -- Separates numbered label and caption
local label_sep1 -- 1st label separater part will have same style as label
local label_sep2 -- 2nd label separater part will have same style as caption

local cap_width -- string as percentage
local cap_wid_as_frac -- percent converted to fraction
local cap_space -- distance between caption and image
local cap_width_in -- caption width in inches
local cap_h_position
local gl_html_padding_table = {} -- init global html padding specs
local custom_html_padding_table = {} -- Init html padding specs
local padding_h -- horizontal padding in inches between image and text
local padding_v -- vertical padding in inches between image and text
local latex_figure_type
local docx_extra_v_space = 0.12 * twips_per_in

-- Caption text lists
local cap_text_sizes = {"small", "normal", "large"}
local cap_ltx_text_sizes = { -- Caption text sizes
    ["small"] = '\\small{X}',
    ["normal"] = "\\normalsize{X}",
    ["large"] = '\\large{X}'
}
local cap_html_text_sizes = { -- Caption text sizes
    ["small"] = 'smaller',
    ["normal"] = "medium",
    ["large"] = 'larger'
}
local cap_docx_text_sizes = { -- Caption text sizes
    ["small"] = '<w:sz w:val="20" />',
    ["normal"] = '<w:sz w:val="24" />',
    ["large"] = '<w:sz w:val="28" />'
}
local text_styles_list = {
    "plain", "normal", "italic", "bold", "oblique", "bold-oblique",
    "bold-italic"
}
local affirm_list = {"true", "yes", "false", "no"}
local docx_cap_par_style = "" -- Initialize paragraph frame style
local docx_cap_text_styles = { -- Text style Open Office codes
    ["plain"] = '<w:b w:val="false"/><w:i w:val="false"/>',
    ["normal"] = '<w:b w:val="false"/><w:i w:val="false"/>',
    ["italic"] = '<w:i w:val="true"/>',
    ["bold"] = '<w:b w:val="true"/>',
    ["oblique"] = '<w:i w:val="true"/>',
    ["bold-oblique"] = '<w:b w:val="true"/><w:i w:val="true"/>',
    ["bold-italic"] = '<w:b w:val="true"/><w:i w:val="true"/>'
}
local ltx_cap_text_styles = { -- Text style latex/PDF codes
    -- ["plain"] = "\\textrm{X}",
    -- ["normal"] = "\\textrm{X}",
    ["plain"] = "{X}",
    ["normal"] = "{X}",
    ["italic"] = '\\textit{X}',
    ["oblique"] = '\\textit{X}',
    ["bold"] = '\\textbf{X}',
    ["bold-oblique"] = '\\textit{\\textbf{X}}',
    ["bold-italic"] = '\\textit{\\textbf{X}}'
}
local ltx_cap_text_alignment = { -- Caption text alignment
    ["left"] = '\\raggedright',
    ["center"] = '\\centering',
    ["right"] = '\\raggedleft'
    -- ["left"] = '\\begin{left}X\\end{left}',
    -- ["center"] = '\\begin{center}X\\end{center}',
    -- ["right"] = '\\begin{right}X\\end{right}'
}

-- local doc_specific_i = 4 -- 'Document-type-specific' column of image params table
local doctypes = {"html", "epub", "docx", "pdf", "latex", "gfm", "markdown"}
local doctype_overrides = {} -- Will contain any document-type-specific overrides
local doctype = string.match(FORMAT, "[%a]+")
-- if doctype == "pdf" then doctype = "latex" end -- Pdf is produced via latex
print("Format: " .. doctype)

local ptr -- General purpose counter/pointer

-- META FUNCTION — Meta stores variables used in images filter
function Meta(meta)
    local err = ""
    local papersize -- Printed page size
    local i
    local j
    local key
    local value
    local done = false
    local ptr = 1
    repeat -- Initialize table of image parameters
        image_params[valid_img_attr_names[ptr]] = {nil, nil, nil}
        ptr = ptr + 1
    until ptr > #valid_img_attr_names

    -- Specify param value defaults
    image_params = {
        ["width"] = {"50%", nil, nil},
        ["columns"] = {"1", nil, nil},
        ["position"] = {"center", nil, nil},
        ["v_padding"] = {".15in", nil, nil},
        ["h_padding"] = {".15in", nil, nil},
        ["cap_width"] = {"90%", nil, nil},
        ["cap_space"] = {".15in", nil, nil},
        ["cap_position"] = {"above", nil, nil},
        ["cap_h_position"] = {"center", nil, nil},
        ["cap_text_align"] = {"left", nil, nil},
        ["cap_text_font"] = {"", nil, nil},
        ["cap_text_size"] = {"normal", nil, nil},
        ["cap_text_style"] = {"plain", nil, nil},
        ["cap_label"] = {"", nil, nil},
        ["cap_label_sep"] = {": ", nil, nil},
        ["cap_label_style"] = {"plain", nil, nil},
        ["adjust_frame_ht"] = {nil, nil, nil},
        ["pdf_anchor_strict"] = {"false", nil, nil},
        ["close_frame"] = {"false", nil, nil},
        ["keep_with_next"] = {"4", nil, nil},
        ["md_cap_ht_adj"] = {"0", nil, nil}
    }
    reset_img_params() -- Init variables before next image

    gl_html_padding_table = {
        dimToInches(image_params["v_padding"][default_i]) * pixels_per_in,
        dimToInches(image_params["h_padding"][default_i]) * pixels_per_in,
        dimToInches(image_params["v_padding"][default_i]) * pixels_per_in,
        dimToInches(image_params["h_padding"][default_i]) * pixels_per_in
    }
    for i = 1, 4, 1 do -- Refresh custom table with global table
        custom_html_padding_table[i] = gl_html_padding_table[i]
    end
    ltx_cap_h_pos = image_params["cap_h_position"][default_i] -- Latex/PDF caption horizontal position

    -- Page widths from papersize
    local papersizes = { -- Widths of page types
        ["letter"] = "8.5in",
        ["legal"] = "8.5in",
        ["ledger"] = "11in",
        ["tabloid"] = "17in",
        ["executive"] = "7.25in",
        ["ansi c"] = "22in",
        ["ansi d"] = "34in",
        ["ansi e"] = "44in",
        ["a0"] = "841mm",
        ["a1"] = "594mm",
        ["a2"] = "420mm",
        ["a3"] = "297mm",
        ["a4"] = "210mm",
        ["a5"] = "148mm",
        ["a6"] = "105mm",
        ["a7"] = "74mm",
        ["a8"] = "52mm"
    }
    -- if stringify(meta.papersize) ~= nil then
    if meta.papersize ~= nil then
        papersize = string.lower(stringify(meta.papersize))
        if papersizes[papersize] ~= nil then
            page_width = dimToInches(papersizes[papersize])
        else
            -- page_width = dimToInches("8.5in") -- If no page spec, fall back to Lettersize
            err_msg = "Bad page size ('" .. papersize ..
                          "') specified in 'papersize' header.\n"
            print(err_msg)
        end
    end
    if meta.geometry ~= nil then
        geometryVars = getGeometries(stringify(meta.geometry)) -- Get string with geometry params
        if geometryVars["pagewidth"] ~= nil then
            page_width = dimToInches(geometryVars["pagewidth"]) -- Get printed page width in inches
        end
        if geometryVars["left"] ~= nil then
            l_mar = dimToInches(geometryVars["left"]) -- Get left margin in inches
        end
        if geometryVars["right"] ~= nil then
            r_mar = dimToInches(geometryVars["right"]) -- Get right margin in inches
        end
        pg_text_width = page_width - l_mar - r_mar
    end
    -- print("Papersize: " .. papersize .. "; page_width: " .. page_width ..
    --           "; l_mar: " .. l_mar .. "; r_mar: " .. r_mar)
    -- Gather any global image parameters in Meta section
    doctype_overrides = {} -- Clear record of doc-type-specific overrides
    ptr = 1 -- Init pointer
    if meta.imageplacement ~= nil then
        local glParStr = stringify(meta.imageplacement)
        glParStr = string.gsub(glParStr, "“", '"') -- Clean of any Pandoc open quotes that disables standard expressions
        glParStr = string.gsub(glParStr, "”", '"') -- Clean of any Pandoc open quotes that disable standard expressions
        -- print("Processing globals: " .. glParStr)
        repeat -- Gather any meta-specified global image parameters
            i, j = string.find(glParStr, "[%a%:%_]+%s*=", ptr) -- Look for param name
            if i == nil then
                done = true
                break
            end
            key = trim(string.sub(glParStr, i, j - 1))
            ptr = j
            value = string.match(string.sub(glParStr, j + 1, j + 50),
                                 "[%%%-%+%_%w%.%:%s]+")
            if value == nil then
                done = true
                break
            end
            ptr = j + 1
            err = recordParam(key, value, global_i, doctype_overrides) -- Save information
            if #err > 0 then -- If error
                err_msg = err_msg .. err .. "\n"
            end
        until done
    else
        print("No 'imageplacement' statement found in Meta section.")
    end
    -- for ptr = 1, #doctype_overrides, 1 do -- print all overrides
    --     print("Global override number " .. ptr .. " is: " ..
    --               doctype_overrides[ptr][1][2])
    -- end
    doctype_override(global_i, doctype_overrides) -- Override any parameters where doc-specific override indicated
    return meta
end

-- **************************************************************************************************
-- Reset these variables before next image
function reset_img_params()
    -- err_msg = "" -- Reset error message
    for ptr = 1, #valid_img_attr_names, 1 do -- Reset all param vals for current image
        image_params[valid_img_attr_names[ptr]][this_i] = nil
    end
    -- frame_position = image_params["position"][default_i] -- Default image frame position
    -- padding_h = dimToInches(image_params["h_padding"][default_i]) -- horizontal padding in inches between image and text
    -- padding_v = dimToInches(image_params["v_padding"][default_i]) -- vertical padding in inches between image and text
    -- docx_padding_h = dimToInches(image_params["h_padding"][default_i])
    -- docx_padding_v = dimToInches(image_params["v_padding"][default_i])
end

-- **************************************************************************************************
-- Image function;
function Image(img)
    reset_img_params()
    src = img.src
    local err = ""
    local pos_center -- Horizontal center of image
    local float -- Float status; true or false
    cap_text = stringify(img.caption)
    image_id = img.label

    html_style = "" -- Reset
    cap_html_style = ""
    docx_cap_par_style = ""
    cap_text_html_style = ""
    cap_text_docx_style = ""
    cap_text_ltx_style = "X" -- Style affecting latex/pdf caption (italic, bold, font, size)
    caption_ltx_style = ""
    cap_label_html_style = ""
    cap_label_docx_style = ""
    cap_label_ltx_style = "X" -- Style affecting latex/pdf caption label (italic, bold, font, size)
    cap_text_style = image_params["cap_text_style"][default_i]
    ltx_position = ""
    cap_position = image_params["cap_position"][default_i]

    cap_label = ""
    cap_lbl = "" -- Composed label text
    cap_label_style = image_params["cap_label_style"][default_i]
    cap_label_sep = "" -- Separates numbered label and caption
    label_sep1 = "" -- 1st label separater part will have same style as label
    label_sep2 = "" -- 2nd label separater part will have same style as caption

    -- custom_html_padding_table = gl_html_padding_table -- Init html padding specs
    for i = 1, 4, 1 do -- Refresh custom table with global table
        custom_html_padding_table[i] = gl_html_padding_table[i]
    end

    image_num = image_num + 1
    if image_num > 1 then
        err_msg = "" -- Reset error message. Allows including Meta global errors in first error msg
    end
    local parStr = tostring(img.attributes)
    -- print("\nFor image " .. src) -- New line

    img_wd, img_ht = GetImageWidthHeight(src) -- Read image dimensions from file
    img_ratio = img_ht / img_wd -- ratio
    if #img.attributes ~= 0 then
        -- Gather attributes and ensure each attribute name is valid
        local r = ""
        local name = ""
        local val = ""
        doctype_overrides = {} -- Clear record of doc-type-specific overrides
        for ptr = 1, #img.attributes, 1 do -- Gather parameters from image
            r =
                r .. "Image attribute item: " .. img.attributes[ptr][1] .. " - " ..
                    img.attributes[ptr][2] .. '\n'
            name = img.attributes[ptr][1]
            val = img.attributes[ptr][2]
            err = recordParam(name, val, this_i, doctype_overrides) -- Record values from image attributes
            if #err > 0 then err_msg = err_msg .. err end
        end
        doctype_override(this_i, doctype_overrides) -- Override any param for which doc-type constraint indicated
    end

    -- ptr = 1 -- Init counter
    -- repeat -- Print complete table
    --     v = valid_img_attr_names[ptr] -- Get next name from table of valid parameters
    --     print("image_param", v, image_params[v][default_i],
    --           image_params[v][global_i], image_params[v][this_i])
    --     ptr = ptr + 1
    -- until ptr > #valid_img_attr_names

    -- Get any label embedded in caption
    i, j = string.find(tostring(img.caption[#img.caption]), "label{.+}")
    if j ~= nil then
        img_label =
            string.sub(tostring(img.caption[#img.caption]), i + 6, j - 1) -- Get label
    else
        img_label = "fig_" .. bookmark
        bookmark = bookmark + 1
    end

    -- **************************************************************************************************
    -- Prep values for constructing output

    width_in, err = dimToInches(getParam("width")) -- Get image width in inches
    if #err == 0 then -- If no error
        width_entered = getParam("width")
    else
        err_msg = err_msg .. err
        width_entered = image_params["width"][default_i] -- Enter default
    end

    -- Frame position relative to left and right margins
    val, source = getParam("position")
    if verify_entry(val,
                    {"left", "center", "right", "float-left", "float-right"}) then
        frame_position = val
    else
        frame_position = image_params["position"][default_i]
        err_msg = err_msg .. "Bad position ('" .. val .. "')" .. source
    end
    i, j = string.find(frame_position, "-")
    if i ~= nil then -- Accommodate "float"
        frame_pos = string.sub(frame_position, i + 1, 20)
    else
        frame_pos = frame_position
    end

    val, par_source = getParam("columns") -- Width divisor for adjusting image width   
    if val ~= nil then
        if tonumber(val) >= 1 and tonumber(val) <= 20 then
            columns = math.floor(tonumber(val))
        else
            err_msg = err_msg .. "'columns' must be between 1 and 20"
        end
    end

    val, par_source = getParam("v_padding") -- Frame vertical padding   
    padding_v, err = dimToInches(val)
    if #err == 0 then -- If no error
        custom_html_padding_table[1] = padding_v * pixels_per_in
        custom_html_padding_table[3] = padding_v * pixels_per_in
        docx_padding_v = padding_v
    else
        err_msg = err_msg .. err .. par_source
        custom_html_padding_table[1] = gl_html_padding_table[1]
        custom_html_padding_table[3] = gl_html_padding_table[3]
        docx_padding_v = dimToInches(image_params["v_padding"][default_i])
    end

    val, par_source = getParam("h_padding") -- Frame horizontal padding   
    padding_h, err = dimToInches(val)
    if #err == 0 then -- If no error
        custom_html_padding_table[2] = padding_h * pixels_per_in
        custom_html_padding_table[4] = padding_h * pixels_per_in
        docx_padding_h = padding_h
    else
        err_msg = err_msg .. err .. par_source
        custom_html_padding_table[2] = gl_html_padding_table[2]
        custom_html_padding_table[4] = gl_html_padding_table[4]
        docx_padding_h = dimToInches(image_params["h_padding"][default_i])
    end

    val, par_source = getParam("cap_position") -- Caption position relative to figure 
    if verify_entry(val, {"above", "below"}) then
        cap_position = val
    else
        cap_position = image_params["cap_position"][default_i]
        err_msg = err_msg .. "Bad caption position value ('" .. val .. "')" ..
                      par_source
    end

    val = getParam("cap_width") -- Caption width
    cap_width = val
    i, j = string.find(tostring(val), "%d+") -- Get dimension
    cap_wid_as_frac = tonumber(string.sub(val, i, j)) / 100 -- Get cap width as percentage
    cap_width_in = cap_wid_as_frac * width_in
    cap_html_style = cap_html_style .. "width:" .. cap_width .. "; "

    val, par_source = getParam("cap_space") -- Space between caption and image
    cap_space, err = dimToInches(val)
    if #err == 0 then -- If no error
        if not (cap_space >= 0 and cap_space <= 1) then
            cap_space = image_params["cap_space"][default_i]
            err_msg = err_msg .. "Space between caption and image (" ..
                          par_source .. ") must be between 0 and 1in."
        end
    end

    val, par_source = getParam("cap_h_position") -- Caption horizontal position relative to frame
    if verify_entry(val, {"left", "center", "right"}) then
        cap_h_position = val
        if (val == "left") then
            cap_html_style = cap_html_style ..
                                 "margin-left:0px; margin-right:auto; "
        elseif (val == "right") then
            cap_html_style = cap_html_style ..
                                 "margin-right:0px; margin-left:auto; "
        elseif (val == "center") then
            cap_html_style = cap_html_style .. "margin:auto; "
        end
    else
        cap_h_position = image_params[name][default_i]
        err_msg = err_msg .. "Bad caption horizontal position value ('" ..
                      getParam("cap_h_position") .. "')" .. par_source
    end

    val = getParam("cap_text_font") -- Caption font family
    if val ~= nil then
        cap_text_font = val -- Get caption font
        cap_text_html_style = cap_text_html_style .. "font-family:" ..
                                  cap_text_font .. "; "
    end

    val, par_source = getParam("cap_text_align") -- Caption text align
    if verify_entry(val, {"left", "center", "right"}) then
        cap_text_align = val
    else
        cap_text_align = image_params["cap_text_align"][default_i]
        err_msg = err_msg .. "Bad caption text alignment value ('" .. val ..
                      "')" .. par_source
    end

    val, par_source = getParam("cap_text_style") -- Caption type-face style
    if verify_entry(val, text_styles_list) then
        cap_text_style = val -- Get caption style
        if (cap_text_style == "bold" or cap_text_style == "bold-oblique" or
            cap_text_style == "bold-italic") and FORMAT:match "html" then
            cap_text_html_style = cap_text_html_style .. "font-weight:" ..
                                      "bold" .. "; "
            if cap_text_style == "bold-oblique" or cap_text_style ==
                "bold-italic" then
                cap_text_html_style = cap_text_html_style .. "font-style:" ..
                                          "italic" .. "; "
            end
        else
            cap_text_html_style = cap_text_html_style .. "font-style:" ..
                                      cap_text_style .. "; "
            cap_text_docx_style = cap_text_docx_style ..
                                      docx_cap_text_styles[cap_text_style]
            cap_text_ltx_style = string.gsub(cap_text_ltx_style, "X",
                                             ltx_cap_text_styles[cap_text_style])
        end
    else
        err_msg = err_msg .. "Bad caption style name ('" .. val .. "')" ..
                      par_source
    end

    val, par_source = getParam("cap_text_size") -- Caption text size
    if val ~= nil then
        if verify_entry(val, cap_text_sizes) then
            cap_text_size = val -- Get caption font size
            cap_text_html_style = cap_text_html_style .. "font-size:" ..
                                      cap_html_text_sizes[cap_text_size] .. "; "
            cap_text_docx_style = cap_text_docx_style ..
                                      cap_docx_text_sizes[cap_text_size]
            cap_text_ltx_style = string.gsub(cap_text_ltx_style, "X",
                                             cap_ltx_text_sizes[cap_text_size])
        else
            err_msg = err_msg .. "Bad caption size ('" .. val .. "')" ..
                          par_source
        end
    end

    val = getParam("cap_label") -- Caption figure label, e.g. 'Figure', allowing sequencial numbering of custom label
    if val ~= nil and #cap_text > 0 then
        cap_label = val
        if cap_labels[cap_label] == nil then
            cap_labels[cap_label] = 1
        else
            cap_labels[cap_label] = cap_labels[cap_label] + 1 -- Increment sequence number
        end
    end

    val, par_source = getParam("cap_label_style") -- Caption figure label style
    if (val ~= nil and #val > 1) then
        if verify_entry(val, text_styles_list) then
            cap_label_style = val
            if (cap_label_style == "bold" or cap_label_style == "bold-oblique" or
                cap_label_style == "bold-italic") and FORMAT:match "html" then
                cap_label_html_style = cap_label_html_style ..
                                           "font-weight:bold; "
                if cap_label_style == "bold-oblique" or cap_label_style ==
                    "bold-italic" then
                    cap_label_html_style =
                        cap_label_html_style .. "font-style:italic" .. "; "
                end
            else
                if cap_label_style == "plain" then
                    cap_label_style = "normal"
                end
                cap_label_html_style = cap_label_html_style .. "font-style:" ..
                                           cap_label_style .. "; font-weight:" ..
                                           "normal" .. "; "
                cap_label_docx_style = cap_label_docx_style ..
                                           docx_cap_text_styles[cap_label_style]
                cap_label_ltx_style = string.gsub(cap_label_ltx_style, "X",
                                                  ltx_cap_text_styles[cap_label_style])
            end
        else
            err_msg = err_msg .. "Bad caption label style name ('" .. val ..
                          "')" .. par_source
        end
    end

    val = getParam("cap_label_sep") -- Separator between caption figure label number, e.g. ": ", and caption.
    if val ~= nil and val ~= "" then
        val = string.gsub(val, "[%“%”%‘%’]", "")
        cap_label_sep = val
    else
        cap_label_sep = ""
    end

    val, par_source = getParam("adjust_frame_ht") -- Latex/PDF imgage wrap height adjust - A text-wrapped Latex/PDF image sometimes will have an extended wrap area at the bottom. In such cases, this provides for an 'adjustment' value to shorten/lengthen wrap area. 
    adjust_frame_ht = val
    if adjust_frame_ht ~= nil then
        if type(adjust_frame_ht) ~= integer and
            (tonumber(adjust_frame_ht) < -99 or tonumber(adjust_frame_ht) > 99) then
            err_msg = err_msg .. "Bad latex height adjustment value ('" ..
                          tostring(adjust_frame_ht) .. "')" .. par_source ..
                          ". It should be an integer, e.g., '10'.\n"
            adjust_frame_ht = nil
        else
            adjust_frame_ht = tonumber(adjust_frame_ht)
        end
    end

    val, par_source = getParam("pdf_anchor_strict") -- Indicates strictness of image float anchor
    if (val ~= nil) then
        if verify_entry(val, affirm_list) then
            pdf_anchor_strict = val
        else
            pdf_anchor_strict = image_params["pdf_anchor_strict"][default_i]
            err_msg = err_msg ..
                          "Invalid indicator of image anchor strictness ('" ..
                          tostring(val) .. "')" .. par_source ..
                          ". It should be 'true', 'false', 'yes' or 'no'.\n"
        end
    end

    val, par_source = getParam("close_frame") -- Indicates margin should be restored after image
    if (doctype == "pdf" or doctype == "latex") then
        if verify_entry(val, affirm_list) then
            close_frame = val
        else
            close_frame = image_params["close_frame"][default_i]
            err_msg = err_msg .. "Invalid indicator of close_frame ('" ..
                          tostring(val) .. "') for image " .. par_source ..
                          ". It should be 'true', 'false', 'yes' or 'no'.\n"
            print(err_msg)
        end
    end

    val, par_source = getParam("keep_with_next") -- Indicates margin should be restored after image
    if tonumber(val) > 2 then
        keep_with_next = val
    else
        keep_with_next = image_params["keep_with_next"][default_i]
        err_msg = err_msg .. "Invalid indicator of keep_with_next ('" ..
                      tostring(val) .. "') for image " .. par_source ..
                      ". It must be 3 or more.\n"
    end

    val, par_source = getParam("md_cap_ht_adj") -- Caption text size
    if val ~= nil then
        if not (tonumber(val) < -20 or tonumber(val) > 21) then
            md_cap_ht_adj = val -- Get caption font size
        else
            md_cap_ht_adj = image_params["md_cap_ht_adj"][default_i]
            err_msg = err_msg ..
                          "Your markdown caption vertical containment adjustment ('" ..
                          val .. "') must be between -20 and +20 for image " ..
                          par_source
        end
    end

    -- **************************************************************************************************
    -- All entered values have been gathered. Now we process values and prep for output.

    i, j = string.find(frame_position, "float") -- Is figure floated?
    if i == nil then -- If caption not floated 
        float = false
    else
        float = true
    end
    -- Get width values
    wd = getParam("width")
    i, j = string.find(wd, "%%") -- If width expressed as percentage, use that value
    if i ~= nil then
        wid_frac = tonumber(string.sub(wd, 1, i - 1)) / 100
    else
        wid_frac = dimToInches(wd) / pg_text_width -- MODIFY TO ACTUAL PAGE WIDTH
    end
    wid_percent = wid_frac * 100 .. "%"

    if (frame_position == "left") then
        html_style = html_style .. "margin-right:auto; margin-left:0px; " ..
                         htmlPad(custom_html_padding_table, '', '', '', '0') ..
                         "; " -- Add to html style
        docx_wrap = "notBeside"

    elseif (frame_position == "right") then
        html_style = html_style .. "margin-right:0px; margin-left:auto; " ..
                         htmlPad(custom_html_padding_table, '', '0', '', '') ..
                         "; "
        docx_wrap = "notBeside"
    elseif (frame_position == "float-left") then
        html_style = html_style ..
                         "float:left; margin-right:auto; margin-left:0px; " ..
                         htmlPad(custom_html_padding_table, '', '', '', '0') ..
                         "; "
        docx_wrap = "auto"
    elseif (frame_position == "float-right") then
        html_style = html_style ..
                         "float:right; margin-right:0px; margin-left:auto; " ..
                         htmlPad(custom_html_padding_table, '', '0', '', '') ..
                         "; "
        docx_wrap = "auto"
    elseif (frame_position == "center" or img.attributes.position == nil) then
        html_style = html_style .. "margin-right:auto; margin-left:auto; " ..
                         htmlPad(custom_html_padding_table, '', '0', '', '0') ..
                         "; "
        docx_wrap = "notBeside"
    end

    -- Get caption components
    if cap_label ~= nil and cap_label ~= "" then -- If figure type label specified, e.g., 'Figure', then compose numbered caption label
        cap_label_sep = string.gsub(cap_label_sep, "_", " ") -- Enables space char in separator entered as "\_"
        cap_lbl =
            getParam("cap_label") .. " " .. -- Compose numbered caption label
            cap_labels[getParam("cap_label")] -- Yes, so record
        if #cap_label_sep > 0 then -- If specified separator between label and caption
            i, j = string.find(cap_label_sep, "^%S*")
            x = string.sub(cap_label_sep, 1, 2)
            if i ~= nil then -- If first char(s) of separator are non-space
                label_sep1 = string.sub(cap_label_sep, i, j) -- Will have same style as label
                label_sep2 = string.sub(cap_label_sep, j + 1, 50) -- Anything after space has caption style
                if label_sep2 == nil then label_sep2 = "" end
            else
                label_sep1 = ""
                label_sep2 = cap_label_sep
            end
        end
    else
        cap_lbl = "" -- No figure type label
    end

    -- Add cap text alignment to text_styles_list
    cap_html_style = cap_html_style .. "text-align:" .. cap_text_align .. "; "
    docx_text_align_xml = '<w:jc w:val="' .. cap_text_align .. '" />'
    -- caption_ltx_style = caption_ltx_style ..
    --                         ltx_cap_text_alignment[cap_text_align]

    -- *************************************************************************
    -- HTML/Epub/markdown documents prep
    if (FORMAT:match "html" or FORMAT:match "epub" or FORMAT:match "gfm" or
        FORMAT:match "mark.*") then -- For html or markdown documents

        -- Get caption html
        cp = "<span style='" .. cap_text_html_style .. "'><span style='" ..
                 cap_label_html_style .. "'>" .. cap_lbl .. label_sep1 ..
                 "</span>" .. label_sep2 .. cap_text .. "</span>"

        -- Define html style
        html_style = html_style .. "width:" .. width_entered .. "; " -- Add width to html style
        if (cap_position == "above") then
            if #cap_text > 0 then
                cap_html = -- Place within div
                "<div style='" .. cap_html_style .. "padding-bottom:" ..
                    dimToInches(getParam("v_padding")) * pixels_per_in .. "px'>" ..
                    cp .. "</div>"
                -- cap_md = cap_md .. '\n'
            else
                cap_html = ""
                -- cap_md = ""
            end
            results_html =
                "<div id='" .. img_label .. "' style='" .. html_style .. "'>" ..
                    cap_html .. "<img src='" .. src .. "' width='100%'/></div>"
        elseif (cap_position == "below") then
            if #cap_text > 0 then
                cap_html = "<div style='" .. cap_html_style .. "padding-top:" ..
                               dimToInches(getParam("v_padding")) *
                               pixels_per_in .. "px'>" .. cp .. "</div>"
                -- cap_md = '\n\n<br />\n\n' .. cap_md
                -- cap_md = '\n\n<br />\n\n' .. cap_md
            else
                cap_html = ""
                -- cap_md = ""
            end
            results_html =
                "<div id='" .. img_label .. "' style='" .. html_style ..
                    "'><img src='" .. src .. "' width='100%'/>" .. cap_html ..
                    "</div>"
            results = results_html
        end

        -- Markdown documents prep
        if FORMAT:match "mark.*" or FORMAT:match "gfm" then -- For markdown documents
            img_md = '<p align="' .. frame_pos .. '"><img src="' .. src ..
                         '" width="' .. wid_percent .. '"></p>'
            pre_cap_md = '<p align="' .. cap_text_align .. '">'
            cap_md = pre_cap_md .. cp .. "</p>" -- Default
            cap_mar_eq = (1 - wid_frac * cap_wid_as_frac) / 2 -- Caption margin for centered
            mar_dif = ((wid_frac - wid_frac * cap_wid_as_frac)) -- Centered caption L margin
            mar_dif_half = mar_dif / 2
            cap_mar_lrg = 1 - (wid_frac * cap_wid_as_frac) -- Caption R margin

            ch_per_in = 16 -- Approximated char per inches
            px_per_line = 20 -- Approximated line leading
            lns = #cap_text / (cap_width_in * ch_per_in)
            cap_ht = math.floor(lns * px_per_line) *
                         (1.8 + tonumber(md_cap_ht_adj) / 10)
            -- print("#cap_text: " .. #cap_text .. "; cap_width_in: " ..
            --           cap_width_in .. "; lns: " .. lns .. "; cap_ht: " .. cap_ht)

            -- if string.match(frame_position, "float") == nil then -- If not floated image
            if not float then -- Not floated
                delta_l = 0
                delta_r = 0
                if cap_h_position == "left" then
                    delta_l = 0 -- Offset if caption align left
                    delta_r = mar_dif
                elseif cap_h_position == "center" then
                    delta_l = mar_dif_half -- Offset if caption align center
                    delta_r = mar_dif_half
                elseif cap_h_position == "right" then
                    delta_l = mar_dif
                    delta_r = 0 -- Offset if caption align right
                end
                if frame_pos == "left" then
                    cap_md = pre_cap_md ..
                                 '<img src="./images-md/1-px.png" width="' ..
                                 delta_l * 100 .. '%" height="' .. cap_ht ..
                                 'px" align="left"><img src="./images-md/1-px.png" width="' ..
                                 (cap_mar_lrg - delta_l) * 100 .. '%" height="' ..
                                 cap_ht .. 'px" align="right">' .. cp .. '</p>'
                elseif (frame_pos == "center") then
                    cap_md = pre_cap_md ..
                                 '<img src="./images-md/1-px.png" width="' ..
                                 (cap_mar_eq - mar_dif_half + delta_l) * 100 ..
                                 '%" height="' .. cap_ht ..
                                 'px" align="left"><img src="./images-md/1-px.png" width="' ..
                                 (cap_mar_eq - mar_dif_half + delta_r) * 100 ..
                                 '%" height="' .. cap_ht .. 'px" align="right">' ..
                                 cp .. "</p>"
                elseif frame_pos == "right" then
                    cap_md = pre_cap_md ..
                                 '<img src="./images-md/1-px.png" width="' ..
                                 delta_r * 100 .. '%" height="' .. cap_ht ..
                                 'px" align="right"><img src="./images-md/1-px.png" width="' ..
                                 (cap_mar_lrg - delta_r) * 100 .. '%" height="' ..
                                 cap_ht .. '" align="left">' .. cp .. '</p>'
                end
                if (cap_position == "above") then
                    results_md = cap_md .. img_md
                else
                    results_md = img_md .. cap_md
                end
            else -- Image floated
                if frame_pos == "left" then
                    al = "right"
                else
                    al = "left"
                end
                if #cap_text > 0 then -- If caption
                    fc = '<figcaption style="margin-' .. al .. ':' .. 10 ..
                             '%">' .. cp .. '<br><br></figcaption>'
                else
                    fc = ""
                end
                results_md = '<figure><img src="' .. src .. '" align="' ..
                                 frame_pos .. '" width="' .. wid_percent ..
                                 '"><img src="./images-md/1-px.png" width="' ..
                                 padding_h * pixels_per_in .. '" height="' ..
                                 cap_ht .. 'px" align="' .. frame_pos .. '">' ..
                                 fc .. '</figure>'
            end
        end
        if FORMAT:match "mark.*" or FORMAT:match "gfm" then -- For markdown documents
            results = results_md
        else
            results = results_html
        end

        -- *************************************************************************
        -- Latex/PDF documents prep
    elseif FORMAT:match "latex" then -- For Latex/PDF documents
        print("Now processing latex/PDF for " .. src)
        if close_frame == "true" or close_frame == "yes" then
            pdf_restore_mar = "\\vfill"
        else
            pdf_restore_mar = ""
        end
        cap_txt = "" -- Reset
        src = string.gsub(src, "%%20", " ") -- Latex requires substituting real space for '%20'
        i, j = string.find(src, ".gif") -- Warn that GIF graphics cannot be converted to latex/pdf
        if i ~= nil then
            err_msg = err_msg .. "GIF images (like " .. src ..
                          ") cannot be used when creating Latex or PDF files. Please substitute a '.png, '.jpg', or other graphic file.\n"
            src = "./images-md/Cannot use GIF for pdf.png"
        end
        if adjust_frame_ht ~= nil then -- If wrap lines adjustment specified
            ltx_adjust_lns = "[" .. adjust_frame_ht .. "]" -- Compose code for it
        else
            ltx_adjust_lns = ""
        end
        local fp = tostring(frame_position)
        if string.match(fp, "float") ~= nil then -- If floated image, determine if strict anchors
            pdf_anchors = {
                ["left"] = {["true"] = "l", ["false"] = "L"},
                ["right"] = {["true"] = "r", ["false"] = "R"}
            }
            pdf_anchor_str = pdf_anchors[frame_pos][pdf_anchor_strict] -- Get code indicating anchor strictness
        else
            pdf_anchor_str = "L" -- Default
        end

        ltx_positions = {
            ["left"] = {'\\begin{figure}[htb]\\centering', 'flushleft'},
            ["center"] = {'\\begin{figure}[htb]\\centering', 'center'},
            ["right"] = {'\\begin{figure}[htb]\\centering', 'flushright'},
            ["float-left"] = {
                '\\begin{wrapfigure}' .. ltx_adjust_lns .. '{' .. pdf_anchor_str ..
                    '}{X\\linewidth}\\centering', 'flushleft'
            },
            ["float-right"] = {
                '\\begin{wrapfigure}' .. ltx_adjust_lns .. '{' .. pdf_anchor_str ..
                    '}{X\\linewidth}\\centering', 'flushright'
            }
        }
        ltx_position = ltx_positions[frame_position][1]
        ltx_cap_h_pos = ltx_positions[frame_position][2]
        i, j = string.find(ltx_position, "{%a+}") -- Get object type: 'figure' or 'wrapfigure'
        latex_figure_type = string.sub(ltx_position, i, j) -- Extract type
        if latex_figure_type == "{figure}" or columns > 1 then -- if for unfloated 'figure' or image within table
            graphic_pos = ", " .. frame_position
            graphic_siz_frac = wid_frac
        else -- if for 'wrapfigure'
            graphic_pos = ""
            graphic_siz_frac = 1.0
        end

        if cap_h_position == "left" then
            ltx_cap_l_wd = 0
            ltx_cap_r_wd = 0
        elseif cap_h_position == "right" then
            ltx_cap_l_wd = 1 - cap_wid_as_frac
            ltx_cap_r_wd = 0
        else
            ltx_cap_l_wd = 0.5 - cap_wid_as_frac / 2
            ltx_cap_r_wd = 0
        end
        -- print(
        --     "GRAPHICS - ltx_cap_l_wd: " .. ltx_cap_l_wd .. "; ltx_cap_r_wd: " ..
        --         ltx_cap_r_wd .. "; graphic_siz_frac: " .. graphic_siz_frac ..
        --         "; cap_wid_as_frac: " .. cap_wid_as_frac)
        if latex_figure_type == "{figure}" or tonumber(columns) > 1 then -- if for 'figure' or image within table
            float_frame_comp = 0
            if (cap_position == "above") then
                cap_pdg_above = padding_v -- If not floated, insert space above and below
                cap_pdg_below = cap_space
                lnbr_above = ""
                lnbr_below = "\\linebreak"
            else -- caption is below
                cap_pdg_above = cap_space
                -- cap_pdg_below = padding_v
                lnbr_above = "\\linebreak"
                lnbr_below = ""
            end
        else -- if for floated 'wrapfigure'
            float_frame_comp = -.3
            if (cap_position == "above") then
                cap_pdg_above = 0
                cap_pdg_below = cap_space
                lnbr_above = ""
                lnbr_below = "\\linebreak"
            else
                cap_pdg_above = cap_space
                cap_pdg_below = float_frame_comp
                lnbr_above = "\\linebreak"
                lnbr_below = ""
            end
        end
        if #cap_text > 0 then -- If caption
            cap_txt = caption_ltx_style .. string.gsub(cap_text_ltx_style, "X",
                                                       string.gsub(
                                                           cap_label_ltx_style,
                                                           "X", cap_lbl ..
                                                               label_sep1) ..
                                                           label_sep2 ..
                                                           cap_text) -- Include any style attributes

            cap_txt = "{" .. cap_txt .. "}"

            cap_row = '\\vspace{' .. cap_pdg_above .. 'in}' .. lnbr_above ..
                          '\\begin{minipage}{' .. ltx_cap_l_wd ..
                          '\\linewidth}{~}\\end{minipage}\\begin{minipage}{' ..
                          cap_wid_as_frac .. '\\linewidth}' ..
                          ltx_cap_text_alignment[cap_text_align] .. cap_txt ..
                          '\\end{minipage}\\begin{minipage}{' .. ltx_cap_r_wd ..
                          '\\linewidth}{~}\\end{minipage}' .. '\\vspace{' ..
                          cap_pdg_below .. 'in}' .. lnbr_below
        else
            cap_row = ""
        end

        frame_assembly = "\\begin{" .. ltx_cap_h_pos .. "}\\begin{minipage}{" ..
                             graphic_siz_frac .. "\\linewidth}" -- Outer minipage includes both image and caption

        if cap_position == "above" then -- If above
            frame_assembly = frame_assembly .. cap_row ..
                                 "\\includegraphics[width=" .. 1.0 ..
                                 "\\linewidth" .. graphic_pos .. "]{" .. src ..
                                 "}" .. "\\end{minipage}\\end{" .. ltx_cap_h_pos ..
                                 "}"
        else
            frame_assembly =
                frame_assembly .. "\\includegraphics[width=" .. 1.0 ..
                    "\\linewidth" .. graphic_pos .. "]{" .. src .. "}" ..
                    cap_row .. "\\end{minipage}\n\\end{" .. ltx_cap_h_pos .. "}"
        end
        if latex_figure_type == "{figure}" or tonumber(columns) > 1 then -- if for 'figure' or image within table
            results = frame_assembly .. '\\vspace{' .. padding_v .. 'in}' ..
                          pdf_restore_mar
        else -- if for 'wrapfigure'
            fig_open = string.gsub(ltx_position, "X", wid_frac) -- Insert width if wrapfigure
            -- results = fig_open .. "\\vspace{" .. float_frame_comp .. "in}" ..
            --               frame_assembly .. "\\end" .. latex_figure_type
            results = fig_open .. "\\vspace{" .. float_frame_comp .. "in}" ..
                          frame_assembly .. "\\end" .. latex_figure_type ..
                          '\\vspace{' .. padding_v .. 'in}' .. pdf_restore_mar
        end

        -- *************************************************************************
        -- DOCX prep
    elseif (FORMAT:match "docx" or FORMAT:match "odt") then -- For WORD DOCX documents
        docx_padding_h = math.floor(padding_h * twips_per_in) -- default printed doc horizontal padding in inches between image and text
        docx_padding_v = math.floor(padding_v * twips_per_in)
        docx_cap_space = cap_space * twips_per_in
        -- i, j = string.find(frame_position, "float") -- Is figure floated?
        -- if i == nil or columns > 1 then -- If caption not floated or image in table row cell w/other images
        if not float or columns > 1 then -- If caption not floated or image in table row cell w/other images
            docx_img_frame_wd = pg_text_width / columns
        else -- Figure is floated
            docx_img_frame_wd = width_in
        end
        if frame_pos == "left" then
            pos_center = width_in / columns / 2
        elseif frame_pos == "center" then
            pos_center = docx_img_frame_wd / 2
        elseif frame_pos == "right" then
            pos_center = docx_img_frame_wd - (width_in / columns / 2)
        end

        if cap_h_position == "left" then
            cap_docx_ind_l = 0
            -- cap_docx_ind_l = pos_center - width_in / columns / 2
            cap_docx_ind_r = docx_img_frame_wd -
                                 (cap_docx_ind_l + cap_width_in / columns)
        elseif cap_h_position == "center" then
            cap_docx_ind_l = pos_center - cap_width_in / columns / 2
            cap_docx_ind_r = docx_img_frame_wd - cap_docx_ind_l - cap_width_in /
                                 columns
        elseif cap_h_position == "right" then
            cap_docx_ind_l = docx_img_frame_wd - cap_width_in / columns
            cap_docx_ind_r = 0
        end
        if #cap_text_docx_style > 0 then -- If specifying caption format then
            cap_text_docx_style = "<w:rPr>" .. cap_text_docx_style .. '</w:rPr>'
        else
            cap_text_docx_style = '<w:rStyle w:val="Caption-text" />' -- Use Word template custom caption style
        end
        if #cap_label_docx_style > 0 then -- If specifying caption format then
            cap_label_docx_style = "<w:rPr>" .. cap_label_docx_style ..
                                       '</w:rPr>'
        else
            cap_label_docx_style = '<w:rStyle w:val="Caption-text" />' -- Use Word template custom caption style
        end
    end -- End if

    -- *************************************************************************
    -- HTML/Epub/markdown doc format COMPOSITION
    if (FORMAT:match "html" or FORMAT:match "epub" or FORMAT:match "gfm") or
        FORMAT:match "mark.*" then
        if (#err_msg > 1) then
            results = "<span style='color:red'>ERROR IN IMAGE INFORMATION - " ..
                          err_msg .. "</span>\n\n" .. results
            print("\nEncountered error: " .. err_msg .. "\n")
        end
        if FORMAT:match "html" or FORMAT:match "epub" then
            print("Writing html image")
            return pandoc.RawInline('html', results) -- html or epub
        elseif FORMAT:match "gfm" then
            print("Writing gfm image")
            return pandoc.RawInline('gfm', results) -- gfm (github flavored markdown)
        elseif FORMAT:match "mark.*" then
            print("Writing markdown image")
            return pandoc.RawInline('markdown', results) -- markdown
        end

        -- *************************************************************************
        -- Latex/PDF doc format COMPOSITION
    elseif (FORMAT:match "latex") then -- Latex/PDF
        print("Writing latex/pdf image")
        if (#err_msg > 1) then
            err_msg = string.gsub(err_msg, "_", "\\_")
            results = "\\textcolor{red}{[ERROR IN IMAGE INFORMATION - " ..
                          err_msg .. "]}\n\n" .. results
            print("\nEncountered error: " .. err_msg .. "\n")
        end
        return pandoc.RawInline('latex', results)

        -- *************************************************************************
        -- Word docx format COMPOSITION
    elseif (FORMAT:match "docx") then
        print("Writing docx image")
        if (#err_msg > 1) then
            er_msg =
                "<w:rPr><w:color w:val='DD0000' /></w:rPr><w:t>[ERROR IN IMAGE INFORMATION - " ..
                    err_msg ..
                    "]<w:br w:type='line' /></w:t><w:rPr><w:color w:val='auto' /></w:rPr>"
        else
            er_msg = ""
        end
        -- i, j = string.find(frame_position, "float") -- Is figure floated?
        -- if i == nil then -- If caption not floated 
        --     float = false
        -- else
        --     float = true
        -- end
        if (cap_position == "above") then -- If caption above
            if #cap_text > 0 then -- If caption
                space_above_caption = docx_padding_v
                space_below_caption = docx_cap_space
                space_above_image = 0
                space_below_image = docx_padding_v
                docx_cap_keep_w_next = "<w:keepNext/>"
                docx_img_keep_w_next = ""
                if float then space_above_caption = 0 end
            else
                space_above_image = docx_padding_v
                space_below_image = docx_padding_v
                docx_img_keep_w_next = ""
            end
        elseif (cap_position == "below") then -- If caption below
            if #cap_text > 0 then -- If caption
                space_above_image = docx_padding_v
                space_below_image = 0
                space_above_caption = docx_cap_space -- Tweak to compensate for extra space added automatically
                space_below_caption = docx_padding_v
                docx_cap_keep_w_next = ""
                docx_img_keep_w_next = "<w:keepNext/>"
                if float then space_above_image = 0 end
            else
                space_above_image = docx_padding_v
                space_below_image = docx_padding_v
                docx_img_keep_w_next = ""
            end
        end
        docx_cap_par_style = '<w:pPr><w:ind w:left="' .. cap_docx_ind_l *
                                 twips_per_in .. '" w:right = "' ..
                                 cap_docx_ind_r * twips_per_in .. '" />' ..
                                 docx_text_align_xml
        img.attributes.width = inchesToPixels(width_in / columns) - padding_h *
                                   2 -- Ensure width expressed as pixels
        if #cap_text > 0 then -- If caption
            docx_cap_pre = '<w:keepLines/>' .. docx_cap_keep_w_next ..
                               '<w:spacing w:before="' .. space_above_caption ..
                               '" w:after="' .. space_below_caption ..
                               '" w:beforeAutospacing="0" />'
            print("docx_cap_pre: " .. docx_cap_pre)
        end
        docx_img_pre = '<w:bookmarkStart w:id="0" w:name="' .. img_label ..
                           '"/><w:bookmarkEnd w:id="0"/><w:pPr>' ..
                           docx_img_keep_w_next .. '<w:spacing w:before="' ..
                           space_above_image .. '" w:after="' ..
                           space_below_image .. '" /><w:jc w:val="' .. frame_pos ..
                           '"/></w:pPr>'
        docx_new_par = '</w:p><w:p>'
        if not float then -- If caption not floated 
            if (cap_position == "above") then -- If caption above
                if #cap_text > 0 then -- If caption
                    results_cap = docx_cap_par_style .. docx_cap_pre ..
                                      '</w:pPr><w:r>' .. cap_text_docx_style ..
                                      cap_label_docx_style .. '<w:t>' .. cap_lbl ..
                                      label_sep1 .. '</w:t></w:r><w:r>' ..
                                      cap_text_docx_style ..
                                      '<w:t xml:space="preserve">' .. label_sep2 ..
                                      cap_text .. '</w:t></w:r>' .. docx_new_par
                else
                    results_cap = ""
                end
                results = {
                    pandoc.RawInline('openxml', results_cap .. docx_img_pre),
                    img
                }
            else -- Caption below
                if #cap_text > 0 then -- If caption
                    results_cap = docx_cap_par_style .. docx_cap_pre ..
                                      '</w:pPr>><w:r>' .. cap_text_docx_style ..
                                      cap_label_docx_style .. '<w:t>' .. cap_lbl ..
                                      label_sep1 .. '</w:t></w:r><w:r>' ..
                                      cap_text_docx_style ..
                                      '<w:t xml:space="preserve">' .. label_sep2 ..
                                      cap_text .. '</w:t></w:r>'
                else
                    results_cap = ""
                end
                results = {
                    pandoc.RawInline('openxml', docx_img_pre), img,
                    pandoc.RawInline('openxml', docx_new_par .. results_cap)
                }

            end
        else -- If caption floated
            results_pre = '<w:pPr><w:framePr w:w="' ..
                -- tostring(inchesToTwips(width_in - padding_h)) ..
                              tostring(inchesToTwips(width_in)) ..
                              '" w:hSpace="' .. docx_padding_h .. '" w:vSpace="' ..
                              docx_padding_v .. '" w:wrap="' .. docx_wrap ..
                              '" w:vAnchor="text" w:hAnchor="margin" w:xAlign="' ..
                              frame_pos .. '" w:y="' .. inchesToTwips(0.1) ..
                              '"/><w:spacing w:before="0" w:after="0"/>' ..
                              docx_text_align_xml .. '</w:pPr>'
            if (cap_position == "above") then
                if #cap_text > 0 then -- If caption
                    results_cap = docx_cap_par_style .. docx_cap_pre ..
                                      '</w:pPr><w:r>' .. er_msg .. '</w:r><w:r>' ..
                                      cap_text_docx_style ..
                                      cap_label_docx_style .. '<w:t>' .. cap_lbl ..
                                      label_sep1 .. '</w:t></w:r><w:r>' ..
                                      cap_text_docx_style ..
                                      '<w:t xml:space="preserve">' .. label_sep2 ..
                                      cap_text .. '</w:t></w:r></w:p><w:p>'
                else
                    results_cap = ""
                end
                results = {
                    pandoc.RawInline('openxml',
                                     results_pre .. results_cap .. results_pre),
                    img
                }

            elseif (cap_position == "below") then
                if #cap_text > 0 then -- If caption
                    results_cap = docx_cap_par_style .. docx_cap_pre ..
                                      '</w:pPr><w:r>' .. er_msg .. '</w:r><w:r>' ..
                                      cap_text_docx_style ..
                                      cap_label_docx_style .. '<w:t>' .. cap_lbl ..
                                      label_sep1 .. '</w:t></w:r><w:r>' ..
                                      cap_text_docx_style ..
                                      '<w:t xml:space="preserve">' .. label_sep2 ..
                                      cap_text .. '</w:t></w:r>'
                else
                    results_cap = ""
                end
                results = {
                    pandoc.RawInline('openxml', results_pre), img,
                    pandoc.RawInline('openxml', '</w:p><w:p>' .. results_pre ..
                                         results_cap)
                }

            end
        end
        return results
    end
end

-- **************************************************************************************************
-- Examine param name for any doc-type constraint. If no constraint, simply record into table.
-- If constraint indicated, record in special table used later to override.
function recordParam(name, value, level, overrides)
    local nam = ""
    local i
    local j
    local doctyp = ""
    local doc_specific = false
    local err = ""
    local alt_doctype = doctype -- Accommodates ability to recognize that pdf docs are processed via latex
    if doctype == "latex" then alt_doctype = "pdf" end
    i, j = string.find(name, ":[_%a]+$") -- Get param without doc constraint
    if i ~= nil then -- If constraint indicated
        nam = string.sub(name, i + 1, j) -- Get name without constraint
        i, j = string.find(name, "[_%a]+:") -- Get doc type constraint
        if i ~= nil then -- If doc type prefix indicated
            doctyp = string.sub(name, i, j - 1)
            if verify_entry(doctyp, doctypes) then -- Ensure doctype prefix valid
                doc_specific = true
                -- print("Verified override for spec with prefix: " .. doctyp ..
                --           "; doctype is " .. doctype)
            else
                err = err .. "Invalid file type prefix ('" .. doctyp .. "') " ..
                          id_source(level) .. ". \n" -- Invalid
                doctyp = ""
                doc_specific = false
            end
        end
        if (doc_specific == true and
            (doctyp == real_doctype or doctyp == alt_doctype)) then
            table.insert(overrides, {nam, value})
        end
    else -- No doc type constraint
        nam = name
        doc_specific = false
    end
    if verify_entry(nam, valid_img_attr_names) == false then
        err = err .. "Bad attribute name ('" .. name .. "') " ..
                  id_source(level)
        if #err > 0 then print("Found error: " .. err) end
    end
    if doc_specific == false then
        if #err == 0 then -- Only for valid entries
            image_params[nam][level] = value -- Doc type not specified. Save into table
        end
    end
    return err
end

-- **************************************************************************************************
-- Affects latex/pdf only: Intercept headers and add latex to ensure will not be orphaned. 
-- function Header(lev, s, attr)
function Header(el, s, attr)
    local sec_type -- section or subsection
    local r = ""
    local name = ""
    local val = ""
    local default = "4" -- Default value for keep with next
    local minlines = default
    local err_msg = "" -- Reset error message
    local e_msg
    print("Encountered header with attributes: " .. tostring(el.attributes))
    if #el.attributes ~= 0 then
        -- Gather attributes and ensure each attribute name is valid
        for ptr = 1, #el.attributes, 1 do -- Gather parameters from image
            name = el.attributes[ptr][1]
            val = el.attributes[ptr][2]
            if name == "keep_with_next" then
                if tonumber(val) > 2 then
                    minlines = val
                else
                    err_msg = err_msg ..
                                  "Parameter 'keep_with_next' must be greater than 2. (Heading '" ..
                                  stringify(el.content) .. "') "
                end
            else
                err_msg = err_msg .. "Unrecognized parameter (" .. name ..
                              ") for heading '" .. stringify(el.content) ..
                              "'. "
            end
        end
    end
    if el.level < 2 then -- Get header level
        sec_type = "section"
    else
        sec_type = "subsection"
    end
    if #err_msg > 0 then
        emsg = "\\textcolor{red}{[ERROR IN HEADING INFORMATION - " .. err_msg ..
                   "]}\n\n"
    else
        emsg = ""
    end
    if (FORMAT:match "latex") and el.level > 0 then -- Latex/PDF    -- Must be latex/pdf and cannot be title
        results = emsg .. "\\needspace{" .. minlines .. "\\baselineskip}{" ..
                      '\\hypertarget{' .. el.identifier .. '}{%\n\\' .. sec_type ..
                      '{' .. stringify(el.c) .. '}\\label{' .. el.identifier ..
                      '}}' .. "}"
        return pandoc.RawInline('latex', results)
    else -- if not latex/pdf
        return nil
    end
end

-- Check entry against simple table of allowed values and return true if valid
function verify_entry(e, tbl)
    local result = false
    local i
    local j
    if e ~= nil then
        for i = 1, #tbl, 1 do
            if tbl[i] == e then
                result = true
                break
            end
        end
    end
    return result
end

-- Override any parameter for which a document-specific parameter is specified
function doctype_override(level, overrides)
    local ptr = 1
    local done = false
    local nam
    local x
    repeat
        if overrides[ptr] ~= nil then
            nam = overrides[ptr][1]
            image_params[nam][level] = overrides[ptr][2] -- Override non-doc-specific value
        end
        ptr = ptr + 1
    until ptr > #overrides
end

-- Gather key/value pairs from meta geometry
function getGeometries(params)
    local key
    local value
    local gVars = {} -- init
    local i
    local j
    local ptr = 1 -- Init counter
    repeat
        i, j, key, value = string.find(params, "(%a+)%s*=%s*([%w.]+)", ptr)
        if i == nil then return gVars end
        gVars[key] = value
        ptr = j + 1
    until (key == nil)
    -- return
end

-- Get value for specified parameter
function getParam(p)
    local result
    local level
    local source -- Identify source in case of error with this param
    if image_params[p][this_i] ~= nil then
        level = this_i -- Remember level
        result = image_params[p][level]
    elseif image_params[p][global_i] ~= nil then
        level = global_i
        result = image_params[p][level]
    elseif image_params[p][default_i] ~= nil then
        level = default_i
        result = image_params[p][level]
    else
        result = nil
    end
    return result, id_source(level)
end

function id_source(level) -- Return string that identifies source of parameter issue
    if level == global_i then
        source = " in markdown file Meta 'imageplacement' statement. \n"
    elseif level == this_i then
        source = " specified in markdown file for figure '" .. src .. "'. \n"
    else
        source = ""
    end
    return source
end

-- Return html padding style. Defaults will be used unless overriding spec supplied for a position (top, right, bottom, left)
function htmlPad(pad_tbl, p_top, p_right, p_bottom, p_left)
    local p_string = "padding: "
    local p = {p_top, p_right, p_bottom, p_left}
    local i
    local j
    for i = 1, 4, 1 do
        -- print("p[i]: " .. p[i])
        if (p[i] ~= nil and p[i] ~= '') then pad_tbl[i] = p[i] end
    end
    for i = 1, 4, 1 do p_string = p_string .. pad_tbl[i] .. "px " end
    return (p_string)
end

function trim(s) return s:match "^%s*(.-)%s*$" end

-- **************************************************************************************************
-- Conversion functions

function inchesToTwips(inches) return (inches * twips_per_in) end

function inchesToEMUs(inches) return (inches * emu_per_in) end

function inchesToPixels(inches) return (inches * pixels_per_in) end

function dimToInchesInteger(val) -- Convert any dimension value into inches integer
    return math.floor(dimToInches(val))
end

function dimToInches(val) -- Convert any dimension value into inches
    -- print("DIMTOINCHES got val: " .. tostring(val))
    local i
    local j
    local val_dim
    local err = ""
    -- print("VALUE: " .. tostring(val))
    i, j = string.find(val, "[%d%.]+") -- Get number
    if i ~= nil then -- If number specified
        val_num = string.sub(val, i, j)
        if string.find(val, "%%") then -- If expressed in percentage
            val_in = tonumber(val_num) / 100 * pg_text_width
            val_dim = "%"
        else
            i, j = string.find(val, "[%a]+") -- Get dimension
            if i ~= nil then
                val_dim = string.sub(val, i, j)
                if verify_entry(val_dim, dims) then
                    if string.find(val_dim, "in") then -- If expressed in inches
                        val_in = tonumber(val_num) -- Get value in inches
                    elseif string.find(val_dim, "px") then -- If expressed in pixels
                        val_in = tonumber(val_num) / pixels_per_in -- Get value in inches
                    elseif string.find(val_dim, "cm") then -- If expressed in centimeters
                        val_in = tonumber(val_num) / cm_per_in -- Get value in inches
                    elseif string.find(val_dim, "mm") then -- If expressed in milimeters
                        val_in = tonumber(val_num) / mm_per_in -- Get value in inches
                    end
                else
                    err = "Bad dimension ('" .. val .. "') specified "
                end
            else
                err = "No dimension ('" .. val .. "') indicated "
                val_in = 0
            end
        end
    else
        val_in = 0
        err = "No value ('" .. val .. "') specified "
    end
    return val_in, err
end

-- Get docx vertical padding, to which supplied value is added
function get_docx_padding_v(val)
    if val ~ nil then val = 0 end
    return (docx_padding_v + val) * twips_per_in
end

-- *************************************************************************
--[[
Get Image Size
By: MikuAuahDark
Allows you to get image/video size from most files.
Supported Image/Video Files(by priority order):
1. Portable Network Graphics
2. Windows Bitmap
3. JPEG
4. GIF
5. Photoshop Document
6. Truevision TGA
7. JPEG XR/TIFF*
8. MP4
9. AVI
(*) = experimental
]]
function GetImageWidthHeight(file)
    local file = string.gsub(file, "%%20", " ") -- Remove any excaped spaces
    local fileinfo = type(file)
    if type(file) == "string" then
        file = assert(io.open(file, "rb"))
    else
        fileinfo = file:seek("cur")
    end
    local function refresh()
        if type(fileinfo) == "number" then
            file:seek("set", fileinfo)
        else
            file:close()
        end
    end
    local width, height = 0, 0
    file:seek("set", 1)
    -- Detect if PNG
    if file:read(3) == "PNG" then
        --[[
			The strategy is
			1. Seek to position 0x10
			2. Get value in big-endian order
		]]
        file:seek("set", 16)
        local widthstr, heightstr = file:read(4), file:read(4)
        if type(fileinfo) == "number" then
            file:seek("set", fileinfo)
        else
            file:close()
        end
        width =
            widthstr:sub(1, 1):byte() * 16777216 + widthstr:sub(2, 2):byte() *
                65536 + widthstr:sub(3, 3):byte() * 256 +
                widthstr:sub(4, 4):byte()
        height = heightstr:sub(1, 1):byte() * 16777216 +
                     heightstr:sub(2, 2):byte() * 65536 +
                     heightstr:sub(3, 3):byte() * 256 +
                     heightstr:sub(4, 4):byte()
        return width, height
    end
    file:seek("set")
    -- Detect if BMP
    if file:read(2) == "BM" then
        --[[ 
			The strategy is:
			1. Seek to position 0x12
			2. Get value in little-endian order
		]]
        file:seek("set", 18)
        local widthstr, heightstr = file:read(4), file:read(4)
        refresh()
        width =
            widthstr:sub(4, 4):byte() * 16777216 + widthstr:sub(3, 3):byte() *
                65536 + widthstr:sub(2, 2):byte() * 256 +
                widthstr:sub(1, 1):byte()
        height = heightstr:sub(4, 4):byte() * 16777216 +
                     heightstr:sub(3, 3):byte() * 65536 +
                     heightstr:sub(2, 2):byte() * 256 +
                     heightstr:sub(1, 1):byte()
        return width, height
    end
    -- Detect if JPG/JPEG
    file:seek("set")
    if file:read(2) == "\255\216" then
        --[[
			The strategy is
			1. Find necessary markers
			2. Store biggest value in variable
			3. Return biggest value
		]]
        local lastb, curb = 0, 0
        local xylist = {}
        local sstr = file:read(1)
        while sstr ~= nil do
            lastb = curb
            curb = sstr:byte()
            if (curb == 194 or curb == 192) and lastb == 255 then
                file:seek("cur", 3)
                local sizestr = file:read(4)
                local h = sizestr:sub(1, 1):byte() * 256 +
                              sizestr:sub(2, 2):byte()
                local w = sizestr:sub(3, 3):byte() * 256 +
                              sizestr:sub(4, 4):byte()
                if w > width and h > height then
                    width = w
                    height = h
                end
            end
            sstr = file:read(1)
        end
        if width > 0 and height > 0 then
            refresh()
            return width, height
        end
    end
    file:seek("set")
    -- Detect if GIF
    if file:read(4) == "GIF8" then
        --[[
			The strategy is
			1. Seek to 0x06 position
			2. Extract value in little-endian order
		]]
        file:seek("set", 6)
        width, height = file:read(1):byte() + file:read(1):byte() * 256,
                        file:read(1):byte() + file:read(1):byte() * 256
        refresh()
        return width, height
    end
    -- More image support
    file:seek("set")
    -- Detect if Photoshop Document
    if file:read(4) == "8BPS" then
        --[[
			The strategy is
			1. Seek to position 0x0E
			2. Get value in big-endian order
		]]
        file:seek("set", 14)
        local heightstr, widthstr = file:read(4), file:read(4)
        refresh()
        width =
            widthstr:sub(1, 1):byte() * 16777216 + widthstr:sub(2, 2):byte() *
                65536 + widthstr:sub(3, 3):byte() * 256 +
                widthstr:sub(4, 4):byte()
        height = heightstr:sub(1, 1):byte() * 16777216 +
                     heightstr:sub(2, 2):byte() * 65536 +
                     heightstr:sub(3, 3):byte() * 256 +
                     heightstr:sub(4, 4):byte()
        return width, height
    end
    file:seek("end", -18)
    -- Detect if Truevision TGA file
    if file:read(10) == "TRUEVISION" then
        --[[
			The strategy is
			1. Seek to position 0x0C
			2. Get image width and height in little-endian order
		]]
        file:seek("set", 12)
        width = file:read(1):byte() + file:read(1):byte() * 256
        height = file:read(1):byte() + file:read(1):byte() * 256
        refresh()
        return width, height
    end
    file:seek("set")
    -- Detect if JPEG XR/Tagged Image File (Format)
    if file:read(2) == "II" then
        -- It would slow, tell me how to get it faster
        --[[
			The strategy is
			1. Read all file contents
			2. Find "Btomlong" and "Rghtlong" string
			3. Extract values in big-endian order(strangely, II stands for Intel byte ordering(little-endian) but it's in big-endian)
		]]
        temp = file:read("*a")
        btomlong = {temp:find("Btomlong")}
        rghtlong = {temp:find("Rghtlong")}
        if #btomlong == 2 and #rghtlong == 2 then
            heightstr = temp:sub(btomlong[2] + 1, btomlong[2] + 5)
            widthstr = temp:sub(rghtlong[2] + 1, rghtlong[2] + 5)
            refresh()
            width = widthstr:sub(1, 1):byte() * 16777216 +
                        widthstr:sub(2, 2):byte() * 65536 +
                        widthstr:sub(3, 3):byte() * 256 +
                        widthstr:sub(4, 4):byte()
            height = heightstr:sub(1, 1):byte() * 16777216 +
                         heightstr:sub(2, 2):byte() * 65536 +
                         heightstr:sub(3, 3):byte() * 256 +
                         heightstr:sub(4, 4):byte()
            return width, height
        end
    end
    -- Video support
    file:seek("set", 4)
    -- Detect if MP4
    if file:read(7) == "ftypmp4" then
        --[[
			The strategy is
			1. Seek to 0xFB
			2. Get value in big-endian order
		]]
        file:seek("set", 0xFB)
        local widthstr, heightstr = file:read(4), file:read(4)
        refresh()
        width =
            widthstr:sub(1, 1):byte() * 16777216 + widthstr:sub(2, 2):byte() *
                65536 + widthstr:sub(3, 3):byte() * 256 +
                widthstr:sub(4, 4):byte()
        height = heightstr:sub(1, 1):byte() * 16777216 +
                     heightstr:sub(2, 2):byte() * 65536 +
                     heightstr:sub(3, 3):byte() * 256 +
                     heightstr:sub(4, 4):byte()
        return width, height
    end
    file:seek("set", 8)
    -- Detect if AVI
    if file:read(3) == "AVI" then
        file:seek("set", 0x40)
        width = file:read(1):byte() + file:read(1):byte() * 256 +
                    file:read(1):byte() * 65536 + file:read(1):byte() * 16777216
        height = file:read(1):byte() + file:read(1):byte() * 256 +
                     file:read(1):byte() * 65536 + file:read(1):byte() *
                     16777216
        refresh()
        return width, height
    end
    refresh()
    return nil
end

-- *************************************************************************
-- Define filter with sequence
return {
    traverse = 'topdown',
    {Meta = Meta}, -- Must be first
    {CodeBlock = CodeBlock},
    {Header = Header},
    {Image = Image}
}

