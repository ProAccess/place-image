-- George Markle 22/08/07
-- This filter provides greater control of imgage and caption placement and appearance
local stringify = (require "pandoc.utils").stringify
local err_msg = "" -- Initialize
local src = "" -- Image path
local geometryVars -- Table from markdown meta table with geometry params
local page_width = 8.5 -- Default printed page width in inches
local l_mar = 1 -- Default Left margin in inches
local r_mar = 1 -- Default Right margin in inches
local text_width -- Will hold length of text width (page width minus margins)
local twips_per_point = 20
local points_per_in = 72
local pixels_per_in = 96
local twips_per_in = points_per_in * twips_per_point
local emu_per_in = 635 * twips_per_in
local cm_per_in = 2.54
local bookmark = 1 -- Init figure number
local dims = {"%", "in", "inches", "px", "pixels", "cm"}
local gl_padding_h = .15 -- default horizontal padding in inches between image and text
local gl_padding_v = .10 -- default vertical padding in inches between image and text
gl_html_padding_table = {
    gl_padding_v * pixels_per_in, gl_padding_h * pixels_per_in,
    gl_padding_v * pixels_per_in, gl_padding_h * pixels_per_in
}
local padding_caption = "15px"

-- Meta stores variables used in images filter
-- local vars = {}
function Meta(meta)
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
    print("page_width: " .. page_width)
    return meta
end

-- Main functon;
function Image(img)
    src = img.src
    local cap_text = stringify(img.caption)
    local image_id = img.label
    local label = ""
    local results = "" -- String with code to be returned
    local docx_align_x = "left"
    local docx_wrap = "notBeside"
    local docx_padding_h = gl_padding_h
    local docx_padding_v = gl_padding_v
    local docx_align_x_xml = ""
    local frame_position = "" -- Position specified, e.g., left, float-left, right, float-right, center
    local frame_pos = "" -- Position abbreviated to left, right, center
    local cap_position = ""
    local pdf_position = "" -- PDF image horizontal position and wrap
    local pdf_pos = "center" -- PDF caption horizontal position
    local pdf_text_align -- PDF caption text alignmentq
    local pdf_cap_l_wd
    local pdf_cap_r_wd
    local pdf_cap_h_pos
    local cap_docx_ind_l = 0
    local cap_docx_ind_r = 0
    local cap_html = ""
    local html_style = ""
    local cap_html_style = ""
    local cap_text_html_style = ""
    local caption_text_html_style = ""
    local caption_text_docx_style = ""
    local caption_pdf_style = "" -- Style affecting caption paragraph
    local caption_text_pdf_style = "X" -- Style affecting characters (italic, bold, font, size)
    local caption_text_pdf_align
    local cap_position_default = "above"
    local cap_width -- string as percentage
    local cap_wid -- percent converted to fraction
    local cap_width_in -- caption width in inches
    local cap_width_default = "100%"
    local cap_h_position
    local cap_h_position_default = "center"
    local cap_text_size_default = "90%"; -- Default caption text size
    local cap_text_align = "left" -- default
    local custom_html_padding_table = {} -- Must init first to avoid being alias for gl_html_padding_table
    local custom_html_padding_table = gl_html_padding_table -- Init html padding specs
    local padding_h = gl_padding_h -- horizontal padding in inches between image and text
    local padding_v = gl_padding_v -- vertical padding in inches between image and text
    local latex_figure_type

    -- Caption POSITION lists: begin code, horizontal position
    local pdf_positions = {
        ["left"] = {'\\begin{figure}\\centering', 'flushleft'},
        ["center"] = {'\\begin{figure}\\centering', 'center'},
        ["right"] = {'\\begin{figure}\\centering', 'flushright'},
        ["float-left"] = {
            '\\begin{wrapfigure}{l}{X\\textwidth}\\centering', 'flushleft'
        },
        ["float-right"] = {
            '\\begin{wrapfigure}{r}{X\\textwidth}\\centering', 'flushright'
        }
    }
    -- Caption text lists
    local cap_pdf_text_sizes = { -- Caption text sizes
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
    local docx_cap_par_style = "" -- Initialize paragraph frame style
    local docx_cap_text_styles = { -- Text style Open Document codes
        ["plain"] = "",
        ["italic"] = '<w:i w:val="true"/>',
        ["bold"] = '<w:b w:val="true"/>',
        ["oblique"] = '<w:i w:val="true"/>',
        ["bold-oblique"] = '<w:b w:val="true"/><w:i w:val="true"/>'
    }
    local cap_pdf_text_alignment = { -- Caption text alignment
        ["left"] = '\\raggedright',
        ["center"] = '\\centering',
        ["right"] = '\\raggedleft'
    }
    local pdf_cap_text_styles = { -- Text style latex PDF codes
        ["plain"] = "\\textrm{X}",
        ["italic"] = '\\textit{X}',
        ["bold"] = '\\textbf{X}',
        ["oblique"] = '\\textit{X}',
        ["bold-oblique"] = '\\textit{\\textbf{X}}'
    }
    local valid_attr_names = {
        "width", "position", "h_padding", "v_padding", "cap", "cap_width",
        "cap_position", "cap_h_position", "cap_text_align", "cap_text_size",
        "cap_text_font", "cap_text_style"
    }

    -- Check entered attributes for any misspelling
    local tmp = checkAttributeNames(img.attributes, valid_attr_names) .. "\n" -- If any misspellings, returns error message
    if #tmp then err_msg = tmp end
    print("Initial attribs check err msg:" .. err_msg)
    -- Check of attributes will cause Pandoc to throw error if space found before or after
    -- any attribute equal (=) sign. Will report '0' as number of attributes.
    local status, result = pcall(checkAttributes, img.attributes) -- Check with error catch
    if status == false then
        err_msg = err_msg ..
                      "A space character may not appear before or after any equal (=) sign when specifying information for image " ..
                      src .. "."
    end

    print("Now checking parameters.")
    -- Process parameters

    -- Get any label embedded in caption
    i, j = string.find(tostring(img.caption[#img.caption]), "label{.+}")
    if j ~= nil then
        label = string.sub(tostring(img.caption[#img.caption]), i + 6, j - 1) -- Get label
    else
        label = "fig_" .. bookmark
        bookmark = bookmark + 1
    end
    -- print("Label: " .. label)
    if img.attributes.width ~= nil then
        wd = img.attributes.width -- Get image width
    else
        wd = "50%"
    end

    local width_in = dimToInches(wd) -- Get image width in inches
    html_style = html_style .. "width:" .. wd .. "; " -- Add width to html style

    -- Frame position relative to left and right margins
    if img.attributes.position ~= nil then
        if verify_entry(img.attributes.position, {
            "left", "center", "right", "float-left", "float-right"
        }) then
            frame_position = img.attributes.position
        else
            frame_position = "center"
            err_msg = "Bad position ('" .. img.attributes.position ..
                          "') specified for figure '" .. img.src .. "'"
        end
    else
        frame_position = "center"
    end
    i, j = string.find(frame_position, "-")
    if i ~= nil then
        frame_pos = string.sub(frame_position, i + 1, 20)
    else
        frame_pos = frame_position
    end
    -- print("pdf_position: " .. pdf_position .. "; pdf_pos: " .. pdf_pos)
    -- print("Frame_position: " .. frame_position .. "; Frame_pos: " .. frame_pos)
    pdf_position = pdf_positions[frame_position][1]
    pdf_pos = pdf_positions[frame_position][2]

    -- Frame vertical padding
    if (img.attributes.v_padding ~= nil) then
        padding_v = dimToInches(img.attributes.v_padding)
        -- print("Just got v-padding of :", padding_v)
        custom_html_padding_table[1] = padding_v * pixels_per_in
        custom_html_padding_table[3] = padding_v * pixels_per_in
    end

    -- Frame horizontal padding
    if (img.attributes.h_padding ~= nil) then
        padding_h = dimToInches(img.attributes.h_padding)
        -- print("Just got h-padding of :", padding_h)
        custom_html_padding_table[2] = padding_h * pixels_per_in
        custom_html_padding_table[4] = padding_h * pixels_per_in
        -- print("custom_html_padding_table:" .. stringify(custom_html_padding_table))
    end
    -- Caption position relative to figure
    if img.attributes.cap_position ~= nil then
        if verify_entry(img.attributes.cap_position,
                        {"above", "right", "below", "left"}) then
            cap_position = img.attributes.cap_position
            print("Established cap_position of: " .. cap_position)
        else
            cap_position = "above"
            err_msg = "Bad caption position value ('" ..
                          img.attributes.cap_position .. "') for figure '" ..
                          src .. "'"
            print("Detected bad cap_position of " .. img.attributes.cap_position)
        end
    else
        cap_position = "above"
    end

    -- Caption width
    if (img.attributes.cap_width ~= nil) then
        cap_width = img.attributes.cap_width
    else
        cap_width = cap_width_default
    end
    print("cap_width: " .. cap_width)
    i, j = string.find(tostring(cap_width), "%d+") -- Get dimension
    cap_wid = tonumber(string.sub(cap_width, i, j)) / 100
    cap_width_in = cap_wid * width_in
    print("cap_wid: " .. cap_wid .. "; cap_width_in: " .. cap_width_in)
    cap_html_style = cap_html_style .. "width:" .. cap_width .. "; "

    -- Caption horizontal position relative to frame
    if (img.attributes.cap_h_position ~= nil) then
        print("img.attributes.cap_h_position: " .. img.attributes.cap_h_position)
        if verify_entry(img.attributes.cap_h_position,
                        {"left", "center", "right"}) then
            cap_h_position = img.attributes.cap_h_position
            if (cap_h_position == "left") then
                cap_html_style = cap_html_style ..
                                     "margin-left:0px; margin-right:auto; "
            elseif (cap_h_position == "right") then
                cap_html_style = cap_html_style ..
                                     "margin-right:0px; margin-left:auto; "
            elseif (cap_h_position == "center") then
                cap_html_style = cap_html_style .. "margin:auto; "
            end
        else
            err_msg = "Bad caption horizontal position value ('" ..
                          img.attributes.cap_h_position .. "') for figure " ..
                          src .. "'"
        end
    else
        cap_h_position = cap_h_position_default
    end

    -- Caption text align
    if (img.attributes.cap_text_align ~= nil) then
        if verify_entry(img.attributes.cap_text_align,
                        {"left", "center", "right"}) then
            cap_text_align = img.attributes.cap_text_align
            cap_html_style =
                cap_html_style .. "text-align:" .. cap_text_align .. "; "
            docx_align_x_xml = '<w:jc w:val="' .. cap_text_align .. '" />'
            caption_pdf_style = caption_pdf_style ..
                                    cap_pdf_text_alignment[cap_text_align]
        else
            err_msg = "Bad caption text alignment value ('" ..
                          img.attributes.cap_text_align .. "') for figure " ..
                          src .. "'"
        end
    end

    -- Caption font family
    if (img.attributes.cap_text_font ~= nil) then
        cap_text_font = img.attributes.cap_text_font -- Get caption font
        caption_text_html_style = caption_text_html_style .. "font-family:" ..
                                      cap_text_font .. "; "
    end

    -- Caption type-face style
    if (img.attributes.cap_text_style ~= nil) then
        if verify_entry(img.attributes.cap_text_style,
                        {"plain", "italic", "bold", "oblique", "bold-oblique"}) then
            cap_text_style = img.attributes.cap_text_style -- Get caption style
            if (cap_text_style == "bold" or cap_text_style == "bold-oblique") and
                FORMAT:match "html" then
                caption_text_html_style =
                    caption_text_html_style .. "font-weight:" .. "bold" .. "; "
                if cap_text_style == "bold-oblique" then
                    caption_text_html_style =
                        caption_text_html_style .. "font-style:" .. "italic" ..
                            "; "
                end
            else
                caption_text_html_style =
                    caption_text_html_style .. "font-style:" .. cap_text_style ..
                        "; "
                caption_text_docx_style =
                    caption_text_docx_style ..
                        docx_cap_text_styles[cap_text_style]
                caption_text_pdf_style =
                    string.gsub(caption_text_pdf_style, "X",
                                pdf_cap_text_styles[cap_text_style])
            end
        else
            err_msg = "Bad caption style name ('" ..
                          img.attributes.cap_text_style .. "') for figure " ..
                          src .. "'"
        end
    end

    -- Caption text size
    if (img.attributes.cap_text_size ~= nil) then
        if verify_entry(img.attributes.cap_text_size,
                        {"small", "normal", "large"}) then
            cap_text_size = img.attributes.cap_text_size -- Get caption font size
            caption_text_html_style = caption_text_html_style .. "font-size:" ..
                                          cap_html_text_sizes[cap_text_size] ..
                                          "; "
            caption_text_docx_style = caption_text_docx_style ..
                                          cap_docx_text_sizes[cap_text_size]
            caption_text_pdf_style = string.gsub(caption_text_pdf_style, "X",
                                                 cap_pdf_text_sizes[cap_text_size])
        else
            err_msg = "Bad caption size ('" .. img.attributes.cap_text_size ..
                          "') for figure " .. src .. "'"
        end
    end

    -- Prep values for constructing output
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
        print("Style with Float-left padding: " .. html_style)
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

    -- HTML documents prep
    if (FORMAT:match "html") then -- For html documents

        if (cap_position == "left" or cap_position == "right") then
            cap_html = "<div style='" .. cap_html_style .. "'><span style='" ..
                           caption_text_html_style .. ">" .. cap_text ..
                           "</span></div>"
        end

        if (cap_position == "above") then
            if #cap_text > 0 then
                cap_html =
                    "<div style='" .. cap_html_style .. "padding-bottom:" ..
                        padding_caption .. "'><span style='" ..
                        caption_text_html_style .. "'>" .. cap_text ..
                        "</span></div>"
            else
                cap_html = ""
            end
            results =
                "<div id='" .. label .. " 'style='" .. html_style .. "'>" ..
                    cap_html .. "<img src='" .. src .. "' width='100%'></div>"
        elseif (cap_position == "below") then
            if #cap_text > 0 then
                cap_html = "<div style='" .. cap_html_style .. "padding-top:" ..
                               padding_caption .. "'><span style='" ..
                               caption_text_html_style .. "'>" .. cap_text ..
                               "</span></div>"
            else
                cap_html = ""
            end
            results = "<div id='" .. label .. " ' style='" .. html_style ..
                          "'><img src='" .. src .. "' width='100%'>" .. cap_html ..
                          "</div>"
        end

        -- PDF documents prep
    elseif FORMAT:match "latex" then -- For PDF documents
        print("Now processing latex")
        src = string.gsub(src, "%%20", " ") -- Latex requires substituting real space for '%20'
        i, j = string.find(src, ".gif") -- Warn that GIF graphics cannot be converted to pdf
        if i ~= nil then
            err_msg = "GIF images (like " .. src ..
                          ") cannot be used when creating PDF files. Please substitute a '.png, '.jpg', or other graphic file."
            src = "./templates/Cannot use GIF for pdf.png"
        end
        i, j = string.find(wd, "%%") -- If width expressed as percentage, use that value
        if i ~= nil then
            wd = tonumber(string.sub(wd, 1, i - 1)) / 100
        else
            wd = dimToInches(wd) / page_width -- MODIFY TO ACTUAL PAGE WIDTH
        end
        if #cap_text > 0 then -- If caption
            cap_txt = caption_pdf_style ..
                          string.gsub(caption_text_pdf_style, "X", cap_text) -- Include any style attributes
            if cap_h_position == "left" then
                pdf_cap_l_wd = .02
                pdf_cap_r_wd = wd - cap_wid
            elseif cap_h_position == "right" then
                pdf_cap_l_wd = 1 - cap_wid - .02
                pdf_cap_r_wd = cap_wid
            else
                pdf_cap_l_wd = 0.5 - (cap_wid / 2)
                pdf_cap_r_wd = cap_wid
            end
        end
        i, j = string.find(pdf_position, "{%a+}") -- Get object type: 'figure' or 'wrapfigure'
        latex_figure_type = string.sub(pdf_position, i, j) -- Extract type
        if latex_figure_type == "{figure}" then -- if for 'figure'
            graphic_width = wd
            graphic_pos = ", " .. frame_position
            if #cap_text > 0 then -- If caption text
                if (cap_position == "above") then
                    c_above = "\\vspace*{" .. padding_v .. "in}" .. cap_txt ..
                                  "\\linebreak\\vspace*{" .. padding_v .. "in}"
                    c_below = "\\vspace*{" .. padding_v .. "in}"
                else -- Caption is below
                    c_below = "\\vspace*{" .. padding_v .. "in}\\linebreak" ..
                                  cap_txt .. "\\vspace*{" .. padding_v .. "in}"
                    c_above = "\\vspace*{" .. padding_v .. "in}"
                end
            else -- If no caption text
                c_above = "\\vspace*{" .. padding_v .. "in}"
                c_below = "\\vspace*{" .. padding_v .. "in}"
            end
        else -- if for 'wrapfigure'
            graphic_width = "1.0"
            graphic_pos = ""
            if #cap_text > 0 then
                cap_txt = "{" .. cap_txt .. "}"
                if (cap_position == "above") then
                    c_above = cap_txt ..
                                  "\\linebreak\\linebreak\\vspace*{0.0in}"
                    c_below = ""
                else
                    c_above = ""
                    c_below = "" .. cap_txt .. "\\vspace*{-0.15in}"
                end
            else
                c_above = ""
                c_below = ""
            end
        end
        if latex_figure_type == "{figure}" then -- if for 'figure'
            results = "\\begin{" .. pdf_pos .. "}\\begin{minipage}{" .. wd ..
                          "\\linewidth}" -- Outer minipage includes both image and caption
            if #cap_text > 0 then
                results = results .. "\\begin{minipage}{" .. pdf_cap_l_wd ..
                              "\\linewidth}{~}\\end{minipage}\\begin{minipage}{" ..
                              cap_wid .. "\\linewidth}" .. c_above ..
                              "\\end{minipage}\n"
            end
            results = results .. "\\includegraphics[width=1.0\\textwidth" ..
                          graphic_pos .. "]{" .. src .. "}" .. c_below ..
                          "\\end{minipage}\\end{" .. pdf_pos .. "}"
        else -- if for 'wrapfigure'
            fig_open = string.gsub(pdf_position, "X", wd) -- Insert width if wrapfigure
            results = fig_open .. "\\vspace*{-0.17in}" .. c_above ..
                          "\\captionsetup{labelformat=empty}" ..
                          "\\includegraphics[width=" .. graphic_width ..
                          "\\linewidth" .. graphic_pos .. "]{" .. src ..
                          "}\\label{" .. label .. "}\n" .. c_below .. "\\end" ..
                          latex_figure_type
        end

        -- DOCX and Open Doc XML prep
    elseif (FORMAT:match "docx" or FORMAT:match "odt") then -- For WORD DOCX documents
        docx_padding_h = math.floor(padding_h * twips_per_in) -- default printed doc horizontal padding in inches between image and text
        docx_padding_v = math.floor(padding_v * twips_per_in)
        i, j = string.find(frame_position, "float") -- Is figure floated?
        if i == nil then -- If caption not floated
            cap_frame_wid = text_width
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

        if #caption_text_docx_style > 0 then -- If specifying caption format then
            caption_text_docx_style = "<w:rPr>" .. caption_text_docx_style ..
                                          '</w:rPr>'
        else
            caption_text_docx_style = '<w:rStyle w:val="Caption-text" />' -- Use Word template custom caption style
        end
    end -- End if

    -- HTML doc format COMPOSITION
    if (FORMAT:match "html") then
        print("Writing html")
        if (#err_msg > 1) then
            results =
                "<span style='color:red'>[ERROR IN IMAGE INFORMATION - " ..
                    err_msg .. "]</span>\n\n" .. results
            print("\nEncountered error: " .. err_msg .. "\n")
        end
        print("Composed html: " .. results)
        return pandoc.RawInline('html', results)

        -- PDF doc format COMPOSITION
    elseif (FORMAT:match "latex") then -- PDF
        print("Writing pdf")
        if (#err_msg > 1) then
            results = "\\textcolor{red}{[ERROR IN IMAGE INFORMATION - " ..
                          err_msg .. "]}\n\n" .. results
            print("\nEncountered error: " .. err_msg .. "\n")
        end
        return pandoc.RawInline('latex', results)

        -- WORD DOCX and OPEN-DOC format COMPOSITION
    elseif (FORMAT:match "docx" or FORMAT:match "odt") then
        print("Writing docx")
        if (#err_msg > 1) then
            er_msg =
                "<w:rPr><w:color w:val='DD0000' /></w:rPr><w:t>[ERROR IN IMAGE INFORMATION - " ..
                    err_msg ..
                    "]<w:br w:type='line' /></w:t><w:rPr><w:color w:val='auto' /></w:rPr>"
        else
            er_msg = ""
        end
        img.attributes.width = inchesToPixels(width_in) -- Ensure width expressed as pixels
        i, j = string.find(frame_position, "float") -- Is figure floated?
        if i == nil then -- If caption not floated
            frame_v_space_before = '<w:pPr><w:spacing w:before="' ..
                                       docx_padding_v ..
                                       '" w:beforeAutospacing="0" /></w:pPr>'
            par_v_space_before = '<w:spacing w:before="' .. docx_padding_v ..
                                     '" w:beforeAutospacing="0" />'
            frame_v_space_after = '<w:pPr><w:spacing w:after="' ..
                                      docx_padding_v ..
                                      '" w:afterAutospacing="0" /></w:pPr>'
            par_v_space_after = '<w:spacing w:after="' .. docx_padding_v ..
                                    '" w:afterAutospacing="0" />'
            img_pre = '<w:pPr><w:spacing w:before="' .. docx_padding_v ..
                          '" w:after="' .. docx_padding_v .. '" /><w:jc w:val="' ..
                          docx_align_x .. '"/></w:pPr>'
            img_post = '</w:p><w:p>'
            if (cap_position == "above") then
                print("frame_v_space_after: " .. frame_v_space_after)
                print("par_v_space_after: " .. par_v_space_after)
                if #cap_text > 0 then -- If caption
                    results_cap = frame_v_space_before .. frame_v_space_after ..
                                      docx_cap_par_style .. par_v_space_after ..
                                      '</w:pPr><w:r>' .. caption_text_docx_style ..
                                      '<w:t>' .. cap_text ..
                                      '</w:t></w:r></w:p><w:p>' ..
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
                                      '</w:pPr><w:r>' .. caption_text_docx_style ..
                                      '<w:t>' .. cap_text .. '</w:t></w:r>' ..
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
                              tostring(inchesToTwips(width_in)) ..
                              '" w:hSpace="' .. docx_padding_h .. '" w:vSpace="' ..
                              docx_padding_v .. '" w:wrap="' .. docx_wrap ..
                              '" w:vAnchor="text" w:hAnchor="margin" w:xAlign="' ..
                              docx_align_x .. '" w:y="' .. inchesToTwips(0.1) ..
                              '"/><w:spacing w:before="0" w:after="0"/>' ..
                              docx_align_x_xml .. '</w:pPr>'
            if (cap_position == "above") then
                if #cap_text > 0 then -- If caption
                    results_cap = docx_cap_par_style .. par_v_space_after ..
                                      '</w:pPr><w:r>' .. er_msg ..
                                      caption_text_docx_style .. '<w:t>' ..
                                      cap_text .. '</w:t></w:r></w:p><w:p>' ..
                                      results_pre
                else
                    results_cap = ""
                end
                results = {
                    pandoc.RawInline('openxml', results_pre .. results_cap), img
                }
            elseif (cap_position == "below") then
                if #cap_text > 0 then -- If caption
                    results_cap = docx_cap_par_style .. par_v_space_before ..
                                      '</w:pPr><w:r>' .. caption_text_docx_style ..
                                      '<w:t>' .. er_msg .. cap_text ..
                                      '</w:t></w:r>'
                    print("Printing cap below: " .. results_cap)
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

-- Conversion functions

function inchesToTwips(inches) return (inches * twips_per_in) end

function inchesToEMUs(inches) return (inches * emu_per_in) end

function inchesToPixels(inches) return (inches * pixels_per_in) end

function dimToInchesInteger(val) -- Convert any dimension value into inches integer
    return math.floor(dimToInches(val))
end

function dimToInches(val) -- Convert any dimension value into inches
    i, j = string.find(val, "[%d%.]+") -- Get number
    if i ~= nil then -- If number specified
        val_num = string.sub(val, i, j)
        if string.find(val, "%%") then -- If expressed in percentage
            val_in = tonumber(val_num) / 100 * text_width
            val_dim = "%"
        else
            i, j = string.find(val, "%a+") -- Get dimension
            if i ~= nil then
                val_dim = string.sub(val, i, j)
                if string.find(val_dim, "in") then -- If expressed in inches
                    val_in = tonumber(val_num) -- Get value in inches
                elseif string.find(val_dim, "px") then -- If expressed in pixels
                    val_in = tonumber(val_num) / pixels_per_in -- Get value in inches
                elseif string.find(val_dim, "cm") then -- If expressed in centimeters
                    val_in = tonumber(val_num) / cm_per_in -- Get value in inches
                else
                    err_msg = "Bad dimension ('" .. val ..
                                  "') specified for figure " .. src
                end
            else
                err_msg =
                    "No dimension ('" .. val .. "') indicated for figure " ..
                        src
                val_in = 0
            end
        end
    else
        val_in = 0
        err_msg = "Bad value ('" .. val .. "') specified for figure '" .. src ..
                      "'"
    end
    return (val_in)
end

-- Return html padding style. Defaults will be used unless overriding spec supplied for a position (top, right, bottom, left)
function htmlPad(pad_tbl, p_top, p_right, p_bottom, p_left)
    local p_string = "padding: "
    local p = {p_top, p_right, p_bottom, p_left}
    for i = 1, 4, 1 do
        print("p[i]: " .. p[i])
        if (p[i] ~= nil and p[i] ~= '') then pad_tbl[i] = p[i] end
    end
    for i = 1, 4, 1 do p_string = p_string .. pad_tbl[i] .. "px " end
    return (p_string)
end

-- Check attributes to ensure no spaces before or after equal (=) signs in attributes.
-- Pandoc throws error if so.
function checkAttributes(attrs)
    local x = attrs[1][1] .. ' - ' .. attrs[1][2] -- Triggers error if no attributes recorded because space before or after "="
    r = ""
    for i = 1, #attrs, 1 do
        r = r .. "attribute item: " .. attrs[i][1] .. ' - ' .. attrs[i][2] ..
                '\n'
    end
    return
end

-- Check attributes to ensure each one is a valid attribute name.
function checkAttributeNames(attrs, validAttributes)
    local status -- catches error if value is nil
    local r = ""
    local val = ""
    err = ""
    for i = 1, #attrs, 1 do
        r = r .. "attribute item: " .. attrs[i][1] .. " - " .. attrs[i][2] ..
                '\n'
        if verify_entry(attrs[i][1], validAttributes) == false then
            err = err .. "Bad attribute name ('" .. attrs[i][1] ..
                      "') specified for figure '" .. src .. "'.\n"
        end
    end
    -- print(r)
    return (err) -- Return with any error message
end

-- Check entry against table of allowed values and return true if val_di
function verify_entry(e, tbl)
    local result = false
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

-- Gather key/value pairs from meta geometry
function getGeometries(params)
    local key
    local value
    local gVars = {} -- init
    local ptr = 1 -- Init counter
    repeat
        i, j, key, value = string.find(params, "(%a+)%s*=%s*([%w.]+)", ptr)
        if i == nil then return gVars end
        -- print("NEW KEY/VALUE: " .. key, value)
        gVars[key] = value
        ptr = j + 1
    until (key == nil)
end

-- Define filter with sequence
return {
    traverse = 'topdown',
    {Meta = Meta}, -- (1)
    {Image = Image} -- (2)
}
