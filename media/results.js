
var pepper = {
  context_change: function(context, userid, key ) {

     userid = typeof userid !== 'undefined' ? userid : "None";
     key = typeof key !== 'undefined' ? key : "None";

     context = pepper.standardize_context(context)

      cache = pepper.cached(context)
      if (cache){
          return pepper.update_auto_completion_screen(context, cache)
      }

      $("#loading").show();
      var url = 'http:/pepper-autocomplete.com/api?code=' + context + "&=version=1.0";
      url += "&userid=" + userid + "&key=" + key;
      $.ajax({
          url: url,
          crossDomain: true,
          dataType: "json",
          type: 'GET',
          success: function(data){
            if(data.hasOwnProperty("error")){
                var h = ""
                $("#auto_completion_screen").html(h)
                info_div = "<div class='error'>" + data.error + "</div>"
                $("#auto_completion_screen").append("<div class='card'>" + info_div + "</div>")
            }
            else{
                pepper.update_auto_completion_screen(context, data.results)
            }
        },
          error: function(data) {
              $("#loading").hide();
          }
      });

  },
    standardize_context: function(code_lines){
        for (var i=0; i < code_lines.length; i++) {
            code_lines[i] = $.trim(code_lines[i])
        }

        return code_lines
    },

    cached: function(context){
        if (context == [""]){
           return null
        }
        return null
    },

    tab_complete_string: function(current_line, tab){

        if ((typeof this.current_results !== 'undefined')  && (typeof current_line !== 'undefined')){
            if (this.current_results.length > 0){

                if (tab > this.current_results.length -1){
                    tab = (tab % this.current_results.length)
                }

                result = this.current_results[tab].highlight

                current_line = $.trim(current_line)
                lines_in_result = result.split("\n")
                for (var i=0; i < lines_in_result.length; i++) {
                    line = $.trim(lines_in_result[i])

                    completions = line.split(current_line)
                    if (completions.length > 1){
                        return completions[1]
                    }
                }
                //strip out html markup.
                //result =
                return "" //lines_in_result[0]
            }
        }

    },

    // _get_suitable_match: function(current_line){
    //     for (var i=0; i < lines_in_result.length; i++) {
    //         line = $.trim(lines_in_result[i])

    //         completions = line.split(current_line)
    //         if (completions.length > 1){
    //             return completions[1]
    //         }
    //     }
    // },


    update_auto_completion_screen: function(context, results) {
        this.current_results = results
        this.current_editors = []
        var h = ""
        $("#auto_completion_screen").html(h)

        for (var i=0; i < results.length; i++) {
            file_text = results[i].highlight
            file_source = results[i].file_name


            file_split = file_source.split("\\")
            file_source = "\\" + file_source


            file_source_min = file_split[0] + " | " + file_split[file_split.length - 1]

            var info_div = ""
            //info_div += "<div class='info_div_result' id='result-info-" + i + "'> <a target='_blank' href='/page" + file_source + "'>" + file_source_min + "</a></div>"
            var code_result =""
            code_result += "<div class='code_result' id='result-" + i + "'>" + file_text + "</div>"

            $("#auto_completion_screen").append("<div class='card'>" + info_div + code_result + "</div>")

            var result_editor = ace.edit("result-" + i);
            result_editor.setOptions({
                    maxLines: Infinity
            });
            result_editor.setTheme("ace/theme/twilight");
            //result_editor.setTheme("ace/theme/github");
            result_editor.renderer.setShowGutter(false)
            result_editor.getSession().setMode("ace/mode/python");




            result_editor.setOptions({
                readOnly: true,
                highlightActiveLine: false,
                highlightGutterLine: false
            })

            this.current_editors.push(result_editor)
//            result_editor.renderer.$cursorLayer.element.style.opacity=0
            //setTimeout(function() {
              // editor.gotoLine(154);

                //var marker = result_editor.getSession().addMarker(range, "marker_highlight", "text");
            //}, 100);
        }
        for (var i=0; i < results.length; i++) {
            $("#result-" + i).resize();

        }
        pepper.update_completion_highlighting_on_results(context)
        //$("#auto_completion_screen").html(h)

    },

    update_completion_highlighting_on_results: function(context){

        for (var i=0; i < this.current_editors.length; i++) {
            pepper._get_range_to_higlight(context, i)
        }
    },

    update_completion_highlighting_on_results: function(current_line){
        var Range = ace.require("ace/range").Range


        for (var i=0; i < this.current_results.length; i++) {
            result = this.current_results[i].highlight
            editor = this.current_editors[i]

            lines_in_result = result.split("\n")


            for (var j=0; j < lines_in_result.length; j++) {
                line = $.trim(lines_in_result[j])
                completions = line.split(current_line)
                if (completions.length > 1){
                    row = j + 1
                    index_when_completion_starts = lines_in_result[j].indexOf(current_line)
                    index_when_completion_ends = lines_in_result[j].length

                    var range = new Range(j, index_when_completion_starts, j, index_when_completion_ends);

                    editor.getSession().addMarker(range, "marker_highlight", true);
                    break;
                }
            }


        }
    }

};
pepper.current_results = []
