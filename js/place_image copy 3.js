function placeImage(docformat, parameters) {
  params = parameters.trim();   // Trim leading/trailing white space
  ptr_params_end = params.length;
  results = "";    // Init
  var_nam = ""; // Init as char string
  var_nam_len = 0; // Init as integer
  var_names = []; // Init arrays
  var_values = [];
  counter = 0;
  vars_processed = false;	// Init as not yet processed
  while (vars_processed == false) {	// While processing not yet completed
    divider = params.indexOf("="); // Find name/value divider?
    if (divider >= 0) {	// If found then more to process
      vars_processed = false;
    } else {
      vars_processed = true;  // No more vars to process
    }
    var_nam_len = divider;
    var_nam = params.substr(0, var_nam_len).trim();
    params = params.substr(divider + 1).trim();	// Remove processed portion of line
    ch_delim = params.substr(0, 1); // Check if surrounded by string quotes
    search_area = params.substr(1, params.length);
    next_comma = search_area.indexOf(","); // Get num chars till end
    if (next_comma == -1) { // If no more, value is to end of line
      vars_processed = true;	// Indicate all variables processed
      var_val_len = params.length; // Get remainder of line
    } else {
      vars_processed = false;	// Indicate more variables to process
      var_val_len = next_comma + 1; // Point to end of value
    }

    skip_delimiter = 0;	// Default
    if (ch_delim == '"' || ch_delim == "'") { // Is first char a string delimiter
      found_delim = search_area.indexOf(ch_delim);
      if (found_delim >= 0) {	// If found
        //var_val_len = found_delim - 1; // then end indicated by closing delimiter
        var_val_len = found_delim; // then end indicated by closing delimiter
        skip_delimiter = 1;
      } else { // Not getting string value
        skip_delimiter = 0;
      }
    }
    start_of_val = params.substr(skip_delimiter, params.length).search(/\S/);	// Point to 1st non-white space
    //var_val = params.substr(skip_delimiter + start_of_val, var_val_len - skip_delimiter).trim();	// From 1st non-whitespace to end of value
    var_val = params.substr(skip_delimiter + start_of_val, var_val_len).trim();	// From 1st 				//alert("Var_name: " + var_nam + "; Var_val: " + var_val);
    params = params.substr(Math.max(var_val_len + skip_delimiter, next_comma + 2), params.length).trim(); // Truncate processed params

    //results = results + "\n\nCounter: " + counter + "; Var_nam: " + var_nam + "; Var_val: " + var_val + "; ";
    var_names[counter] = var_nam;	// Record variable name and value
    var_values[counter] = var_val;
    counter = counter + 1;
  } // End while

  results = results + "\n\n" + var_names + " — " + var_values;
  //alert("docformat: " + docformat);

  src = position = caption_html = caption_text = caption_position = style = results = "";	// Initialize parameters
  width = "50%"	// default;
  caption_align = "left";	// default
  //if (docformat == "html") { // For html documents
  if (docformat == "html") { // For html documents
    //docformat == "docx"
    for (v_nam in var_names) {	// For each variable entered
      //alert("v_nam: " + var_names[v_nam]);
      switch (var_names[v_nam]) {
        case "src":
          src = var_values[v_nam];
          break;
        case "width":
          width = var_values[v_nam];
          width_num = Number(width.match(/\b\d+/));	// Get number
          width_dim = width.match(/\D+\b/);	// Get dimension
          width_percent = width.match(/%/);	// Get percentage
          style = style + "width:" + width + "; "
          //alert("Detected Width of " + var_values[v_nam]);
          break;
        case "position":
          if (var_values[v_nam] == "left") {
            style = style + "margin-left:0px; margin-right:auto; padding: 10px 10px 15px 0px; "
          } else if (var_values[v_nam] == "right") {
            style = style + "margin-right:0px; margin-left:auto; padding: 10px 0px 15px 10px; "
          } else if (var_values[v_nam] == "float-left") {
            style = style + "float:left; padding: 10px 10px 15px 0px; ";
          } else if (var_values[v_nam] == "float-right") {
            style = style + "float:right; padding: 10px 0px 15px 10px; ";
          } else if (var_values[v_nam] == "center") {
            style = style + "margin-left:auto; margin-right:auto; padding: 10px 0px 15px 0px; "
          }
          break;
        case "caption":
        case "caption-above":
          caption_position = "above";
          caption_text = var_values[v_nam]; // Get text
          break;
        case "caption-below":
          caption_position = "below"
          caption_text = var_values[v_nam]; // Get text
          break;
        case "caption-left":
          caption_position = "left"
          caption_text = var_values[v_nam]; // Get text
          break;
        case "caption-right":
          caption_position = "right"
          caption_text = var_values[v_nam]; // Get text
          break;
        case "caption-width":
          caption_wid = var_values[v_nam];	// Get caption width
          break;
        case "caption-align":
          caption_align = var_values[v_nam];	// Get caption alignment
          break;
      }
    }

    // Here can add code to reconcile different width dimensions in prep for assembling html below
    if (caption_position == "above" || caption_position == "below") {
      caption_html = "<div id='caption_div' caption_width='" + width + "'><p style='font-style:italic; text-align:" + caption_align + "; padding: 10pt 10pt 10pt 10pt'>" + caption_text + "</p></div>";
    }
    if (caption_position == "left" || caption_position == "right") {
      caption_html = "<div id='caption_div' caption_width='" + width + "'><p style='font-style:italic; text-align:" + caption_align + "; padding: 0 10pt 0 10pt'>" + caption_text + "</p></div>";
    }

    switch (caption_position) {
      case "above":
        results = "<div style='" + style + "'>" + caption_html + "<img src='" + src + "' width='100%'></div>";
        break;
      case "below":
        results = "<div style='" + style + "'><img src='" + src + "' width='100%'>" + caption_html + "</div>";
        break;

      case "left":
        break;
      case "right":
        break;
    }

    //results = "<div width=" + width + " style='" + style + "'><img src='" + src + "'></div>";
    //results = "<div style='" + style + "'><img src='" + src + "' width='" + width + "'></div>";
    //results = "<div width=" + width + " style='" + style + "'><img src='" + "src" + "'></div>";
  } else if (docformat == "docx") { // For Word documents
    //results = "::: { custom - style='Frame-Right' }![](./images-md/availability - curve - 500.png){ width = 250px } :::";
    results = "WORD TEST";
  } else if (docformat == "latex") { // For pdf documents

  } // End if

  return (results);
}
