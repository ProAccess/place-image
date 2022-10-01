--[[  -- George Markle 22/10/01
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
local text_width = 6.5 -- Length of text width (page width minus left and right margins); Set default in case page-type not specified
local twips_per_point = 20
local points_per_in = 72
local pixels_per_in = 96
local twips_per_in = points_per_in * twips_per_point
local emu_per_in = 635 * twips_per_in
local cm_per_in = 2.54
local mm_per_in = 25.4
local bookmark = 1 -- Init figure number
local dims = {"%", "in", "inches", "px", "pixels", "cm", "mm"}

local valid_attr_names =
    { -- Names of valid parameters. Each parameter and its value separated by "="
        "width", -- Image width
        "position", -- horizontal position on page (left, center, right)
        "h_padding", "v_padding", -- padding between image, caption and surrounding text.
        "cap_width", -- Width of caption text. If expressed as percent, will be relative to image width.
        "cap_position", -- above or below. Default is above.
        "cap_h_position", -- horizontal position of caption block relative to image (left, center, right). Default is center.
        "cap_text_align", -- If specified: left, center, right
        "cap_text_size", -- If specified: small, normal, large. Default is normal.
        "cap_text_font", -- If specified, font must be among system fonts. Default is body-text.
        "cap_text_style", -- If specified: plain, italic, bold, bold-oblique, bold-italic. Default is plain.
        "cap_label", -- If specified, can be any, e.g., "Figure", "Photo", "My Fantatic Table", etc.
        "cap_label_style", -- If specified: plain, italic, bold, bold-oblique, bold-italic. Default is plain.
        "cap_label_sep", -- If specified, indicates separater between caption label number and caption, e.g., ": "
        "pdf_adjust_lines" -- Special parameter for latex/pdf output. Provided for those cases where latex misjudges the equivalent line-height of an image. User may adjust vertical wrap, e.g., 10, 12, 15.
    }
local image_params = {} -- Will contain image placement parameters {["param"],{var_default, val_global, val_this}}
local default_i = 1 -- 'Default' column of image params table
local global_i = 2 -- 'Global' column of image params table
local this_i = 3 -- 'This image-specific' column of image params table

local src -- Image source
local width_entered -- Width as entered
local width_in -- Image width in inches
local wid_frac -- Fraction of page width the image width represents
local cap_text -- Caption text
local image_id
local img_label = "" -- From markdown image specification, unique to enable link
local results = "" -- String with code to be returned
local results_img
local docx_align_x
local docx_align_x_xml = ""
local docx_wrap = "notBeside"
local docx_padding_h
local docx_padding_v
local frame_position -- Position specified, e.g., left, float-left, right, float-right, center
local frame_pos = "" -- Position abbreviated to left, right, center
local cap_position = ""
local ltx_position = "" -- Latex/PDF image horizontal position and wrap
local ltx_positions = {} -- Contains doc-specifc code for each possible position
local ltx_pos -- Latex/PDF caption horizontal position
local ltx_text_align -- Latex/PDF caption text alignmentq
local ltx_cap_l_wd
local ltx_cap_r_wd
local ltx_cap_h_pos
local pdf_adjust_lines -- 'Adjustment' value to shorten latex/pdf image wrap area.
local cap_docx_ind_l = 0
local cap_docx_ind_r = 0
local cap_html = ""
local html_style = ""
local cap_text_style
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
local cap_wid -- percent converted to fraction
local cap_width_in -- caption width in inches
local cap_h_position
local gl_html_padding_table = {} -- init global html padding specs
local custom_html_padding_table = {} -- Init html padding specs
local padding_h -- horizontal padding in inches between image and text
local padding_v -- vertical padding in inches between image and text
local latex_figure_type

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
local cap_ltx_text_alignment = { -- Caption text alignment
    ["left"] = '\\raggedright',
    ["center"] = '\\centering',
    ["right"] = '\\raggedleft'
}
local ltx_cap_text_styles = { -- Text style latex/PDF codes
    ["plain"] = "\\textrm{X}",
    ["normal"] = "\\textrm{X}",
    ["italic"] = '\\textit{X}',
    ["bold"] = '\\textbf{X}',
    ["oblique"] = '\\textit{X}',
    ["bold-oblique"] = '\\textit{\\textbf{X}}',
    ["bold-italic"] = '\\textit{\\textbf{X}}'
}

-- local doc_specific_i = 4 -- 'Document-type-specific' column of image params table
local doctypes = {"html", "epub", "docx", "pdf", "latex"}
local doctype_overrides -- Will contain any document-type-specific overrides
local doctype = string.match(FORMAT, "[%a]+")
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
        image_params[valid_attr_names[ptr]] = {nil, nil, nil}
        -- print("Image param: " .. image_params[valid_attr_names[i]])
        ptr = ptr + 1
    until ptr > #valid_attr_names

    -- Specify param value defaults
    image_params["width"][default_i] = "50%"
    image_params["position"][default_i] = "center"
    image_params["v_padding"][default_i] = ".1in"
    image_params["h_padding"][default_i] = ".15in"
    image_params["cap_width"][default_i] = "90%"
    image_params["cap_position"][default_i] = "above"
    image_params["cap_h_position"][default_i] = "center"
    image_params["cap_text_align"][default_i] = "center"
    image_params["cap_text_font"][default_i] = ""
    image_params["cap_text_size"][default_i] = "normal"
    image_params["cap_text_style"][default_i] = "plain"
    image_params["cap_label_sep"][default_i] = ": "
    image_params["cap_label"][default_i] = ""
    image_params["cap_label_style"][default_i] = "plain"

    frame_position = image_params["position"][default_i] -- Default image frame position
    padding_h = dimToInches(image_params["h_padding"][default_i]) -- horizontal padding in inches between image and text
    padding_v = dimToInches(image_params["v_padding"][default_i]) -- vertical padding in inches between image and text
    docx_padding_h = dimToInches(image_params["h_padding"][default_i])
    docx_padding_v = dimToInches(image_params["v_padding"][default_i])
    gl_html_padding_table = {
        dimToInches(image_params["v_padding"][default_i]) * pixels_per_in,
        dimToInches(image_params["h_padding"][default_i]) * pixels_per_in,
        dimToInches(image_params["v_padding"][default_i]) * pixels_per_in,
        dimToInches(image_params["h_padding"][default_i]) * pixels_per_in
    }
    for i = 1, 4, 1 do -- Refresh custom table with global table
        custom_html_padding_table[i] = gl_html_padding_table[i]
    end
    ltx_pos = image_params["cap_h_position"][default_i] -- Latex/PDF caption horizontal position
    -- custom_html_padding_table = gl_html_padding_table -- Init html padding specs
    -- j = ""
    -- for i = 1, 4, 1 do j = j .. custom_html_padding_table[i] .. "; " end
    -- print("INITIAL custom_html_padding_table TABLE: " .. j)

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
        text_width = page_width - l_mar - r_mar
    end
    -- Gather any global image parameters in Meta section
    doctype_overrides = {} -- Clear record of doc-type-specific overrides
    ptr = 1 -- Init pointer
    if meta.imageplacement ~= nil then
        local glParStr = stringify(meta.imageplacement)
        glParStr = string.gsub(glParStr, "“", '"') -- Clean of any Pandoc open quotes that disables standard expressions
        glParStr = string.gsub(glParStr, "”", '"') -- Clean of any Pandoc open quotes that disable standard expressions
        print("Processing globals: " .. glParStr)
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
            print("Just got Meta VAL: " .. tostring(value))
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
    print("ACCUMULATED Meta err_msg: " .. err_msg)
    doctype_override(global_i, doctype_overrides) -- Override any parameters where doc-specific override indicated
    -- print("GETTING PARAMS: " .. stringify(image_params[x][2]))
    -- i = 1
    -- repeat -- initialize table of image parameters
    --     print("After init, global params for item " .. i .. " is: " ..
    --               tostring(image_params[valid_attr_names[i]][2]))
    --     i = i + 1
    -- until i > #valid_attr_names
    -- print("Number params: " .. #image_params)
    -- print("Image global_i: " .. global_i)
    return meta
end

-- **************************************************************************************************
-- Image function;
function Image(img)
    src = img.src
    local err = ""
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
    if #img.attributes ~= 0 then
        -- Gather attributes and ensure each attribute name is valid
        local r = ""
        local name = ""
        local val = ""
        ptr = 1
        repeat -- Reset params for this image
            image_params[valid_attr_names[ptr]][this_i] = nil
            -- print("Image param: " .. image_params[valid_attr_names[i]])
            ptr = ptr + 1
        until ptr > #valid_attr_names
        doctype_overrides = {} -- Clear record of doc-type-specific overrides
        for ptr = 1, #img.attributes, 1 do
            -- print("Normal gather interation: " .. ptr .. "; of #img.attributes: " .. #img.attributes)
            r = r .. "attribute item: " .. img.attributes[ptr][1] .. " - " ..
                    img.attributes[ptr][2] .. '\n'
            name = img.attributes[ptr][1]
            val = img.attributes[ptr][2]
            err = recordParam(name, val, this_i, doctype_overrides)
            if #err > 0 then err_msg = err_msg .. err end
        end
        print("ACCUMULATED Image err_msg: " .. err_msg)
        -- print("ATTRIBUTES: " .. r)
        doctype_override(this_i, doctype_overrides) -- Override any param for which doc-type constraint indicated
    end

    -- ptr = 1 -- Init counter
    -- repeat -- Print complete table
    --     v = valid_attr_names[ptr] -- Get next name from table of valid parameters
    --     print("image_param", v, image_params[v][default_i],
    --           image_params[v][global_i], image_params[v][this_i])
    --     ptr = ptr + 1
    -- until ptr > #valid_attr_names

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
    print("custom_html_padding_table: " .. custom_html_padding_table[1],
          custom_html_padding_table[3], custom_html_padding_table[3],
          custom_html_padding_table[4])
    print("padding_v: " .. padding_v)

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

    val = getParam("cap_width") -- -- Caption width as percentage
    cap_width = val
    i, j = string.find(tostring(val), "%d+") -- Get dimension
    cap_wid = tonumber(string.sub(val, i, j)) / 100
    cap_width_in = cap_wid * width_in
    cap_html_style = cap_html_style .. "width:" .. cap_width .. "; "

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
        cap_html_style = cap_html_style .. "text-align:" .. cap_text_align ..
                             "; "
        docx_align_x_xml = '<w:jc w:val="' .. cap_text_align .. '" />'
        caption_ltx_style = caption_ltx_style ..
                                cap_ltx_text_alignment[cap_text_align]
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
    -- end

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
    if val ~= nil then
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
    print("Just retrieved cap_label_sep of: " .. cap_label_sep)

    val, par_source = getParam("pdf_adjust_lines") -- Latex/PDF imgage wrap height adjust - A text-wrapped Latex/PDF image sometimes will have an extended wrap area at the bottom. In such cases, this provides for an 'adjustment' value to shorten/lengthen wrap area. 
    pdf_adjust_lines = val
    if pdf_adjust_lines ~= nil then
        if type(pdf_adjust_lines) ~= integer and
            (tonumber(pdf_adjust_lines) < -99 or tonumber(pdf_adjust_lines) > 99) then
            err_msg = err_msg .. "Bad latex height adjustment value ('" ..
                          tostring(pdf_adjust_lines) .. "')" .. par_source ..
                          ". It should be an integer, e.g., '10'.\n"
            pdf_adjust_lines = nil
        else
            pdf_adjust_lines = tonumber(pdf_adjust_lines)
        end
    end

    -- **************************************************************************************************
    -- All entered values have been gathered. Now we process values and prep for output.

    if (frame_position == "left") then
        html_style = html_style .. "margin-right:auto; margin-left:0px; " ..
                         htmlPad(custom_html_padding_table, '', '', '', '0') ..
                         "; " -- Add to html style
        docx_align_x = "left"
        docx_wrap = "notBeside"

    elseif (frame_position == "right") then
        html_style = html_style .. "margin-right:0px; margin-left:auto; " ..
                         htmlPad(custom_html_padding_table, '', '0', '', '') ..
                         "; "
        docx_align_x = "right"
        docx_wrap = "notBeside"
    elseif (frame_position == "float-left") then
        html_style = html_style ..
                         "float:left; margin-right:auto; margin-left:0px; " ..
                         htmlPad(custom_html_padding_table, '', '', '', '0') ..
                         "; "
        docx_align_x = "left"
        docx_wrap = "auto"
    elseif (frame_position == "float-right") then
        html_style = html_style ..
                         "float:right; margin-right:0px; margin-left:auto; " ..
                         htmlPad(custom_html_padding_table, '', '0', '', '') ..
                         "; "
        docx_align_x = "right"
        docx_wrap = "auto"
    elseif (frame_position == "center" or img.attributes.position == nil) then
        html_style = html_style .. "margin-right:auto; margin-left:auto; " ..
                         htmlPad(custom_html_padding_table, '', '0', '', '0') ..
                         "; "
        docx_align_x = "center"
        docx_wrap = "notBeside"
    end

    if cap_label ~= nil and cap_label ~= "" then -- If figure type label specified, e.g., 'Figure', then compose numbered caption label
        cap_label_sep = string.gsub(cap_label_sep, "_", " ") -- Enables space char in separator entered as "\_"
        print("Examining cap_label_sep: " .. cap_label_sep)
        cap_lbl =
            getParam("cap_label") .. " " .. -- Compose numbered caption label
            cap_labels[getParam("cap_label")] -- Yes, so record
        if #cap_label_sep > 0 then -- If specified separator between label and caption
            i, j = string.find(cap_label_sep, "^%S*")
            x = string.sub(cap_label_sep, 1, 2)
            print("Seperator start and stop - i: " .. i .. "; j: " .. j ..
                      "; found: " .. string.sub(cap_label_sep, i, j) ..
                      " which should equal " .. x)
            if i ~= nil then -- If first char(s) of separator are non-space
                label_sep1 = string.sub(cap_label_sep, i, j) -- Will have same style as label
                label_sep2 = string.sub(cap_label_sep, j + 1, 50) -- Anything after space has caption style
                if label_sep2 == nil then label_sep2 = "" end
            else
                label_sep1 = ""
                label_sep2 = cap_label_sep
            end
            print(
                "FOUND sep1 = " .. tostring(label_sep1) .. "; label_sep2 = " ..
                    label_sep2 .. "; i = " .. tostring(i) .. "; j = " ..
                    tostring(j))
        end
    else
        cap_lbl = "" -- No figure type label
    end

    -- HTML/Epub documents prep
    if (FORMAT:match "html" or FORMAT:match "epub") then -- For html documents
        html_style = html_style .. "width:" .. width_entered .. "; " -- Add width to html style
        if (cap_position == "above") then
            if #cap_text > 0 then
                cap_html =
                    "<div style='" .. cap_html_style .. "padding-bottom:" ..
                        dimToInches(getParam("v_padding")) * pixels_per_in ..
                        "px'><span style='" .. cap_text_html_style ..
                        "'><span style='" .. cap_label_html_style .. "'>" ..
                        cap_lbl .. label_sep1 .. "</span>" .. label_sep2 ..
                        cap_text .. "</span></div>"
            else
                cap_html = ""
            end
            results = "<div id='" .. img_label .. "' style='" .. html_style ..
                          "'>" .. cap_html .. "<img src='" .. src ..
                          "' width='100%'/></div>"
        elseif (cap_position == "below") then
            if #cap_text > 0 then
                cap_html = "<div style='" .. cap_html_style .. "padding-top:" ..
                               dimToInches(getParam("v_padding")) *
                               pixels_per_in .. "px'><span style='" ..
                               cap_text_html_style .. "'><span style='" ..
                               cap_label_html_style .. "'>" .. cap_lbl ..
                               label_sep1 .. "</span>" .. label_sep2 .. cap_text ..
                               "</span></div>"
            else
                cap_html = ""
            end
            results = "<div id='" .. img_label .. "' style='" .. html_style ..
                          "'><img src='" .. src .. "' width='100%'/>" ..
                          cap_html .. "</div>"
        end

        -- Latex/PDF documents prep
    elseif FORMAT:match "latex" then -- For Latex/PDF documents
        cap_txt = "" -- Reset
        print("Now processing latex/PDF")
        src = string.gsub(src, "%%20", " ") -- Latex requires substituting real space for '%20'
        i, j = string.find(src, ".gif") -- Warn that GIF graphics cannot be converted to latex/pdf
        if i ~= nil then
            err_msg = err_msg .. "GIF images (like " .. src ..
                          ") cannot be used when creating Latex or PDF files. Please substitute a '.png, '.jpg', or other graphic file.\n"
            src = "./images-md/Cannot use GIF for pdf.png"
        end
        wd = getParam("width")
        i, j = string.find(wd, "%%") -- If width expressed as percentage, use that value
        if i ~= nil then
            wid_frac = tonumber(string.sub(wd, 1, i - 1)) / 100
        else
            wid_frac = dimToInches(wd) / page_width -- MODIFY TO ACTUAL PAGE WIDTH
        end
        -- Caption POSITION lists: begin code, horizontal position
        if pdf_adjust_lines ~= nil then -- If wrap lines adjustment specified
            ltx_adjust_lns = "[" .. pdf_adjust_lines .. "]" -- Compose code for it
        else
            ltx_adjust_lns = ""
        end
        ltx_positions = {
            ["left"] = {'\\begin{figure}[htb]\\centering', 'flushleft'},
            ["center"] = {'\\begin{figure}[htb]\\centering', 'center'},
            ["right"] = {'\\begin{figure}[htb]\\centering', 'flushright'},
            ["float-left"] = {
                '\\begin{wrapfigure}' .. ltx_adjust_lns ..
                    '{l}{X\\textwidth}\\centering', 'flushleft'
            },
            ["float-right"] = {
                '\\begin{wrapfigure}' .. ltx_adjust_lns ..
                    '{r}{X\\textwidth}\\centering', 'flushright'
            }
        }
        ltx_position = ltx_positions[frame_position][1]
        ltx_pos = ltx_positions[frame_position][2]
        if #cap_text > 0 then -- If caption
            cap_txt = caption_ltx_style .. string.gsub(cap_text_ltx_style, "X",
                                                       string.gsub(
                                                           cap_label_ltx_style,
                                                           "X", cap_lbl ..
                                                               label_sep1) ..
                                                           label_sep2 ..
                                                           cap_text) -- Include any style attributes
            if cap_h_position == "left" then
                ltx_cap_l_wd = .02
                ltx_cap_r_wd = wid_frac - cap_wid
            elseif cap_h_position == "right" then
                ltx_cap_l_wd = 1 - cap_wid - .02
                ltx_cap_r_wd = cap_wid
            else
                ltx_cap_l_wd = 0.5 - (cap_wid / 2)
                ltx_cap_r_wd = cap_wid
            end
        end

        i, j = string.find(ltx_position, "{%a+}") -- Get object type: 'figure' or 'wrapfigure'
        latex_figure_type = string.sub(ltx_position, i, j) -- Extract type
        if latex_figure_type == "{figure}" then -- if for 'figure'
            local graphic_width_factor = wd
            graphic_pos = ", " .. frame_position
            if #cap_text > 0 then -- If caption text
                if (cap_position == "above") then
                    c_above = "\\vspace{" .. padding_v .. "in}{" .. cap_txt ..
                                  "}\\linebreak\\vspace{" .. padding_v .. "in}"
                    c_below = "\\vspace{" .. padding_v .. "in}"
                else -- Caption is below
                    c_below = "\\vspace{" .. padding_v .. "in}{" .. "" ..
                                  cap_txt .. "}{" .. padding_v .. "in}"
                    c_above = "\\vspace{" .. padding_v .. "in}"
                end
            else -- If no caption text
                c_above = "\\vspace{" .. padding_v .. "in}"
                c_below = "\\vspace{" .. padding_v .. "in}"
            end
        else -- if for 'wrapfigure'
            local width_minus_padding = width_in - padding_h
            graphic_width_factor = width_minus_padding / text_width
            graphic_wd_factor = width_minus_padding / width_in
            -- print("graphic_width_factor: " .. graphic_width_factor)
            -- print("width_in: " .. width_in .. "; padding_h: " .. padding_h ..
            --          "; text_width: " .. text_width ..
            --          "; graphic_width_factor = " .. graphic_width_factor)
            graphic_pos = ""
            if #cap_text > 0 then
                cap_txt = "{" .. cap_txt .. "}"
                if (cap_position == "above") then
                    c_above = "{" .. cap_txt .. "}\\vspace{" .. padding_v ..
                                  "in}"
                    c_below = ""
                else
                    c_above = ""
                    c_below = "{" .. cap_txt .. "}\\vspace{" .. padding_v ..
                                  "in}"
                end
            else
                c_above = ""
                c_below = ""
            end
        end
        if latex_figure_type == "{figure}" then -- if for 'figure'
            results =
                "\\begin{" .. ltx_pos .. "}\\begin{minipage}{" .. wid_frac ..
                    "\\linewidth}" -- Outer minipage includes both image and caption
            if cap_position == "above" and #cap_text > 0 then -- If above
                results = results .. "\\begin{minipage}{" .. ltx_cap_l_wd ..
                              "\\linewidth}{~}\\end{minipage}\\begin{minipage}{" ..
                              cap_wid .. "\\linewidth}" .. c_above ..
                              "\\end{minipage}\n"
            end
            results = results .. "\\includegraphics[width=1.0\\textwidth" ..
                          graphic_pos .. "]{" .. src .. "}"
            if cap_position == "below" and #cap_text > 0 then -- If below
                results = results .. "\\vspace{" .. padding_v ..
                              "in}\\linebreak\\begin{minipage}{" .. ltx_cap_l_wd ..
                              "\\linewidth}{~}\\end{minipage}\\begin{minipage}{" ..
                              cap_wid .. "\\linewidth}" .. c_below ..
                              "\\end{minipage}\n"
            end
            results = results .. "\\end{minipage}\\end{" .. ltx_pos .. "}"
        else -- if for 'wrapfigure'
            fig_open = string.gsub(ltx_position, "X", wid_frac) -- Insert width if wrapfigure
            results = fig_open .. "\\vspace{-0.17in}" .. c_above ..
                          "\\captionsetup{labelformat=empty}" ..
                          "\\includegraphics[width=" .. graphic_wd_factor ..
                          "\\linewidth" .. graphic_pos .. "]{" .. src ..
                          "}\\label{" .. img_label .. "}\n" .. c_below ..
                          "\\end" .. latex_figure_type
        end

        -- DOCX prep
    elseif (FORMAT:match "docx" or FORMAT:match "odt") then -- For WORD DOCX documents
        docx_padding_h = math.floor(padding_h * twips_per_in) -- default printed doc horizontal padding in inches between image and text
        docx_padding_v = math.floor(padding_v * twips_per_in)
        i, j = string.find(frame_position, "float") -- Is figure floated?
        if i == nil then -- If caption not floated
            cap_frame_wid = text_width - padding_h -- Account for padding
        else
            cap_frame_wid = width_in
        end
        if frame_position == "left" then
            pos_center = width_in / 2
        elseif frame_position == "center" then
            pos_center = cap_frame_wid / 2
        else
            pos_center = cap_frame_wid - (width_in / 2)
        end
        if cap_h_position == "left" then
            cap_docx_ind_l = pos_center - width_in / 2
            cap_docx_ind_r = cap_frame_wid - cap_docx_ind_l - cap_width_in
        elseif cap_h_position == "center" then
            cap_docx_ind_l = pos_center - (cap_width_in / 2)
            cap_docx_ind_r = cap_frame_wid - cap_docx_ind_l - cap_width_in
        elseif cap_h_position == "right" then
            cap_docx_ind_l = pos_center + width_in / 2 - cap_width_in
            cap_docx_ind_r = cap_frame_wid - cap_docx_ind_l - cap_width_in
        end
        docx_cap_par_style = '<w:pPr><w:ind w:left="' .. cap_docx_ind_l *
                                 twips_per_in .. '" w:right = "' ..
                                 cap_docx_ind_r * twips_per_in .. '" />' ..
                                 docx_align_x_xml

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

    -- HTML/Epub doc format COMPOSITION
    if (FORMAT:match "html" or FORMAT:match "epub") then
        print("Writing html image")
        if (#err_msg > 1) then
            results = "<span style='color:red'>ERROR IN IMAGE INFORMATION - " ..
                          err_msg .. "</span>\n\n" .. results
            print("\nEncountered error: " .. err_msg .. "\n")
        end
        return pandoc.RawInline('html', results)

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

        -- Word docx format COMPOSITION
    elseif (FORMAT:match "docx") then
        print("Writing docx image")

        --[[         img_docx = -- Experiment to see if we can avoid embedding the full 'Image ' object       
            '<w:drawing><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">\
            <pic:nvPicPr>\
            <pic:cNvPr id="0" name="./images-md/availability-curve-500.png"/>\
            <pic:cNvPicPr/>\
            </pic:nvPicPr>\
            <pic:blipFill>\
            <a:blip r:embed="rId4" cstate="print"/>\
            <a:stretch>\
            <a:fillRect/>\
            </a:stretch/>\
            </pic:blipFill>\
            <pic:spPr>\
            <a:xfrm>\
            <a:off x="0" y="0"/>\
            <a:ext cx="2438400" cy="1828800"/>\
            </a:xfrm>\
            <a:prstGeom rst="rect>\
            <a:avLst/>\
            </a:prstGeom>\
            </pic:spPr>\
            </pic:pic></w:drawing>'
 ]]
        if (#err_msg > 1) then
            er_msg =
                "<w:rPr><w:color w:val='DD0000' /></w:rPr><w:t>[ERROR IN IMAGE INFORMATION - " ..
                    err_msg ..
                    "]<w:br w:type='line' /></w:t><w:rPr><w:color w:val='auto' /></w:rPr>"
        else
            er_msg = ""
        end
        img.attributes.width = inchesToPixels(width_in - padding_h) -- Ensure width expressed as pixels
        frame_v_space_before =
            '<w:pPr><w:spacing w:before="' .. docx_padding_v ..
                '" w:beforeAutospacing="0" /></w:pPr>'
        frame_v_space_after = '<w:pPr><w:spacing w:after="' .. docx_padding_v ..
                                  '" w:afterAutospacing="0" /></w:pPr>'
        par_v_space_before = '<w:spacing w:before="' .. docx_padding_v ..
                                 '" w:beforeAutospacing="0" />'
        par_v_space_after = '<w:spacing w:after="' .. docx_padding_v ..
                                '" w:afterAutospacing="0" />'
        img_pre = '<w:bookmarkStart w:id="0" w:name="' .. img_label ..
                      '"/><w:bookmarkEnd w:id="0"/><w:pPr><w:spacing w:before="' ..
                      docx_padding_v .. '" w:after="' .. docx_padding_v ..
                      '" /><w:jc w:val="' .. docx_align_x .. '"/></w:pPr>'
        img_post = '</w:p><w:p>'
        i, j = string.find(frame_position, "float") -- Is figure floated?
        if i == nil then -- If caption not floated 
            if (cap_position == "above") then -- If caption above
                if #cap_text > 0 then -- If caption
                    results_cap = frame_v_space_before .. frame_v_space_after ..
                                      docx_cap_par_style .. par_v_space_after ..
                                      '</w:pPr><w:r>' .. cap_text_docx_style ..
                                      cap_label_docx_style .. '<w:t>' .. cap_lbl ..
                                      label_sep1 .. '</w:t></w:r><w:r>' ..
                                      cap_text_docx_style ..
                                      '<w:t xml:space="preserve">' .. label_sep2 ..
                                      cap_text .. '</w:t></w:r></w:p><w:p>' ..
                                      frame_v_space_before

                else
                    results_cap = ""
                end
                results = {
                    pandoc.RawInline('openxml', results_cap .. img_pre), img
                }

            else -- Caption below
                if #cap_text > 0 then -- If caption
                    results_cap = docx_cap_par_style .. par_v_space_after ..
                                      '</w:pPr>><w:r>' .. cap_text_docx_style ..
                                      cap_label_docx_style .. '<w:t>' .. cap_lbl ..
                                      label_sep1 .. '</w:t></w:r><w:r>' ..
                                      cap_text_docx_style ..
                                      '<w:t xml:space="preserve">' .. label_sep2 ..
                                      cap_text .. '</w:t></w:r>' ..
                                      frame_v_space_after
                else
                    results_cap = ""
                end
                results = {
                    pandoc.RawInline('openxml', img_pre), img,
                    pandoc.RawInline('openxml', img_post .. results_cap)
                }

            end
        else -- If caption floated
            results_pre = '<w:pPr><w:framePr w:w="' ..
                              tostring(inchesToTwips(width_in - padding_h)) ..
                              '" w:hSpace="' .. docx_padding_h .. '" w:vSpace="' ..
                              docx_padding_v .. '" w:wrap="' .. docx_wrap ..
                              '" w:vAnchor="text" w:hAnchor="margin" w:xAlign="' ..
                              docx_align_x .. '" w:y="' .. inchesToTwips(0.1) ..
                              '"/><w:spacing w:before="0" w:after="0"/>' ..
                              docx_align_x_xml .. '</w:pPr>'
            if (cap_position == "above") then
                if #cap_text > 0 then -- If caption
                    results_cap = docx_cap_par_style .. par_v_space_after ..
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
                    results_cap = docx_cap_par_style .. par_v_space_before ..
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
                    -- pandoc.RawInline('openxml', results_pre .. img_docx),
                    -- pandoc.RawInline('openxml', '</w:p><w:p>' .. results_pre ..
                    --                      results_cap)
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
    -- print("Now am procssing entry: " .. name .. "; value: " .. value ..
    --   "; at level: " .. level)
    i, j = string.find(name, ":[_%a]+$") -- Get param without doc constraint
    if i ~= nil then -- If constraint indicated
        nam = string.sub(name, i + 1, j) -- Get name without constraint
        i, j = string.find(name, "[_%a]+:") -- Get doc type constraint
        if i ~= nil then -- If doc type prefix indicated
            doctyp = string.sub(name, i, j - 1)
            if verify_entry(doctyp, doctypes) then -- Ensure doctype prefix valid
                doc_specific = true
            else
                err = err .. "Invalid file type prefix ('" .. doctyp .. "') " ..
                          id_source(level) .. ". \n" -- Invalid
                doctyp = ""
                doc_specific = false
            end
            -- print("Doc type for param: " .. doctyp)
        end
        if (doc_specific == true and doctyp == doctype) then
            table.insert(overrides, {nam, value})
        end
    else -- No doc type constraint
        nam = name
        doc_specific = false
    end
    -- print("Examining: " .. nam .. " with value of " .. value)
    if verify_entry(nam, valid_attr_names) == false then
        err = err .. "Bad attribute name ('" .. name .. "') " ..
                  id_source(level)
        if #err > 0 then print("FOUND ERROR: " .. err) end
    end
    if doc_specific == false then
        if #err == 0 then -- Only for valid entries
            image_params[nam][level] = value -- Doc type not specified. Save into table
        end
    end
    return err
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
    local i
    local j
    local val_dim
    local err = ""
    -- print("DIMTOINCHES: " .. val)
    i, j = string.find(val, "[%d%.]+") -- Get number
    if i ~= nil then -- If number specified
        val_num = string.sub(val, i, j)
        if string.find(val, "%%") then -- If expressed in percentage
            val_in = tonumber(val_num) / 100 * text_width
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

-- Define filter with sequence
return {
    traverse = 'topdown',
    {Meta = Meta}, -- Must be first
    {CodeBlock = CodeBlock},
    {Image = Image}
}

