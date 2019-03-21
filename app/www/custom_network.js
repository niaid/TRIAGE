Shiny.addCustomMessageHandler("jsondata1",
  function(message){
    var json_data = message;

    var df = []

    json_data.forEach(function(d){
      d = {name: d.name[0], imports: d.imports, weights: d.weights,
            datasource: d.datasource, Confidence: d.Confidence[0], color: d.Color[0]};
      df.push(d)
    })

    //console.log(df);

    // Variables for div and svg dimensions
    var w = 800,
      h = w,
      rx = 380,
      ry = 365,
      m0,
      rotate = 0,
      headSpace = 100,
      rectW = w-640,
      rectH = w-650;

    // empty variables to be populated later
    var clickedData = [],
        splines = [],
        childrenData = {},
        childrenArray = [],
        nClicked = 0,
        numbNovel = 0,
        numbNoNovel = 0;

    // colors for visualization and colormapping to unique node parent names
    var novelColor = "green",
        color1 = "blue",
        color2 = "red",
        color3 = "saddlebrown",
        color12 = "#a09d01",
        color13 = "#6b5b3e",
        color23 = "#ce6702",
        color123 = "#6d1c8e",
        colorMap = [color1, color2, color3, novelColor, color123, color12, color23, color13],
        windowFields = ['Gene Name:', ' ', 'Connections:', 'Confidence:'];

    // network assignments cluster, bundle, and line
    var cluster = d3.layout.cluster()
      .size([360, ry - 120])
    var bundle = d3.layout.bundle();
    var line = d3.svg.line.radial()
      .interpolate("bundle")
      .tension(.85)
      .radius(function(d) { return d.y; })
      .angle(function(d) { return d.x / 180 * Math.PI; });

    // removes the network div once another network is chosen in shiny
    if(d3.select("#graphView1")[0][0].children.length === 1){
      d3.select("#graphView1")[0][0].children[0].remove()
    }

    // main div and svg elements for the network, legend, window, and double click message
    var div = d3.select("#graphView1")
      .attr("class", "d3network")
      .style("top", headSpace + "px")
      .style("width", w + "px")
      .style("height", w + "px")
      .style("position", "absolute")
      .style("-webkit-backface-visibility", "hidden");

    var svG = div.append("svg:svg")
      .attr("width", w)
      .attr("height", w)

    var legend = svG.append("svg:g")
      .attr("transform", "translate(5,5)")

    var svg = svG.append("svg:g")

    var windowArea = svG.append("svg:g")
      .attr("transform", "translate(638,5)")

    windowArea.append("svg:rect")
      .attr("height", rectH)
      .attr("width", rectW)
      .attr("rx", 5)
      .attr("ry", 5)
      .style("stroke", novelColor)
      .style("fill", "none")
      .style("stroke-width", 2);

    var dubsMessage = svG.append("svg:g")
      .attr("transform", "translate(690, 170)")
      .attr("class", "resetButton");

    dubsMessage.append("svg:rect")
      .attr("height", 20)
      .attr("width", 102)
      .attr("rx", 10)
      .attr("ry", 10)
      .style("stroke", "black")
      .style("fill", "none")
      .style("stroke-width", 2);

    dubsMessage.append("svg:text")
      .attr("font-family", "Helvetica")
      .style("text-anchor", "center")
      .attr("dy", 15)
      .attr("dx", 7)
      .text('Click to reset')
      .on("click", mousedbl);

    var windowText = windowArea.selectAll("text")

    windowText.data(windowFields)
      .enter()
        .append("svg:text")
        .attr("class", "vizText")
        .style("fill", "black")
        .attr("transform", function(d) { return "translate(0,20)"; })
        .attr("dy", function(d,i){return(20*i)})
        .attr("dx", 2)
        .text(function(d) { return d; });

    var pathButton = svG.append("svg:g")
      .attr("transform", "translate(715, 200)")
      .attr("class", "pathButton")

    pathButton.append("svg:rect")
      .attr("height", 55)
      .attr("width", 80)
      .attr("rx", 10)
      .attr("ry", 10)
      .style("stroke", "black")
      .style("fill", "none")
      .style("stroke-width", 2);

    pathButtonTxt = ["Highlight", "Clicked", "Pathways"]

    pathButton.selectAll("text")
      .data(pathButtonTxt)
      .enter()
        .append("svg:text")
        .style("text-anchor", "center")
        .attr("dx", 7)
        .attr("dy", function(d, i){return 16*i + 16;})
        .attr("font-family", "Helvetica")
        .text(function(d){return d;})
        .on("click", drawConnections);

    svg.append("svg:path")
      .attr("class", "arc")
      .attr("d", d3.svg.arc().outerRadius(ry - 120).innerRadius(0).startAngle(0).endAngle(2 * Math.PI))
      .on("mousedown", mousedown);

    // find all names of parentNames
    function findParents(classes){
      var map = {};

      function find(data){
        map[data.parent.name] = data.parent.name;
      }

      classes.forEach(function(d) {
        find(d);
      })

      arr = Object.keys(map);
      arr.push(arr.splice(arr.indexOf("Novel"), 1)[0]);

      return arr;
    }

    // Lazily construct the package hierarchy from class names.
    function root(classes) {
      var map = {};

      function find(name, data) {
        var node = map[name], i;
        if (!node) {
          node = map[name] = data || {name: name, children: []};
          if (name.length) {
            node.parent = find(name.substring(0, name.indexOf(".")));
            node.parent.children.push(node);
            node.key = name.substring(name.lastIndexOf(".") + 1);
          }
        }
        return node;
      }

      classes.forEach(function(d) {
        find(d.name, d);
      });

      return map[""];
    }

    // Return a list of imports for the given array of nodes.
    function imports(nodes) {
      var map = {},
          imports = [];

      // Compute a map from name to node.
      nodes.forEach(function(d) {
        map[d.name] = d;
      });

      // For each import, construct a link from the source to target node.
      nodes.forEach(function(d) {
        if (d.imports) d.imports.forEach(function(i) {
          imports.push({source: map[d.name], target: map[i]});
        });
      });

      return imports;
    }

    // setting up nodes , links, splines, and parents for references and visualizations
    // of network graph
    var nodes = cluster.nodes(root(df)),
        links = imports(nodes),
        splines = bundle(links),
        parents = findParents(df);

    // counters for number of novel genes and non-novel genes
    for(i in df){
      if(df[i].parent.name === "Novel"){
        numbNovel ++;
      }
      else{
        numbNoNovel ++;
      }
    }

    // Rotating the network graph to center around hit gene families
    var shiftRotate = -(numbNoNovel)/(numbNovel + numbNoNovel) * 180;
    svg.attr("transform",  "translate(" + rx + "," + ry + ")rotate(" + shiftRotate + ")");

    // Attributing colors to nodes as well as assignment of colored legend text
    var colorMapping = function(df){
      newCols = []
      for(i in df){
        if(!(newCols.includes(df[i].color))){
          newCols.push(df[i].color)
        }
      }
      newCols.splice(newCols.indexOf(novelColor), 1);
      newCols.push(novelColor);
      return newCols;
    }

    startingColors = colorMapping(df)

    var ordColors = []

    for(j in colorMap){
      if(startingColors.includes(colorMap[j])){
        ordColors.push(colorMap[j])
      }
    }

    var novelInd = ordColors.indexOf(novelColor)

    var getLegendColors = function(){
      check = 0
      for(i in parents){
        if(parents[i].includes(" & ")){
          check = 1
        }
      }
      if(check){
        lColors = ["#000000"];
        lColors = lColors.concat(ordColors.slice(0, novelInd+1));
        lColors.push("#000000", "#000000", "#000000");
        lColors = lColors.concat(ordColors.slice(novelInd+1));
      }
      else{
        lColors = ordColors;
      }
      return lColors;
    }

    var legendColors = getLegendColors();

    var pathwayNames = parents.slice(0);

    // fixes the unique pathway names and assigns correct legend text
    var fixPathwayNames = function(pns){
      pathways = ["Pathways:"]
      overlaps = [" ", "Genes in Overlapping", "Pathways:"]
      abc = ["1: ", "2: ", "3: "]
      abcs = ["1 & 2", "1 & 3", "2 & 3", "1 & 2 & 3"]
      n = startingColors.length
      pns = pns.slice(0)
      check = 0
      for(i in pns){
        if(pns[i].includes(" & ")){
          check = 1
        }
      }
      if(!check){
        pns[pns.length-1] = "Novel Genes"
      }
      else{
        for(s in ordColors){
          color = ordColors[s]
          switch (color) {
            case color1:
              nS = abc[0] + pns[startingColors.indexOf(color)];
              pathways.push(nS)
              break;
            case color2:
              nS = abc[1] + pns[startingColors.indexOf(color)];
              pathways.push(nS)
              break;
            case color3:
              nS = abc[2] + pns[startingColors.indexOf(color)];
              pathways.push(nS)
              break;
            case novelColor:
              nS = "Novel Genes";
              pathways.push(nS)
              break;
            case color12:
              nS = abcs[0];
              overlaps.push(nS)
              break;
            case color13:
              nS = abcs[1];
              overlaps.push(nS)
              break;
            case color23:
              nS = abcs[2];
              overlaps.push(nS)
              break;
            case color123:
              nS = abcs[3];
              overlaps.push(nS)
              break;
          }
        }

        // bringing them together
        pnsSort = pathways.concat(overlaps)
        pns = pnsSort
      }
      return pns;
    }

    pathwayNames = fixPathwayNames(pathwayNames);

    // builds the legend
    legend.selectAll("text")
      .data(pathwayNames)
      .enter()
      .append("svg:text")
      .style("fill", function(d, i) {return legendColors[i];})
      .attr("id", function(d, i){return 'text' + i})
      .attr("transform", function(d) {return "translate(0,20)";})
      .attr("dy", function(d,i) {
        return 20*i
      })
      .text(function(d) { return d; });

    // builds the path links in the network
    var path = svg.selectAll("path.link")
        .data(links)
      .enter().append("svg:path")
        .attr("class", function(d) { return "link source-" + d.source.key + " target-" + d.target.key; })
        .attr("d", function(d, i) { return line(splines[i]); })
        .style('stroke', function(d) {
          if(d.source.parent.name === 'Novel'){
            return d.target.color;
          }
          else{
            return d.source.color;
          }
        })
        .style("stroke-opacity", 0.05);

    // builds the nodes for the network as graph elements with circles and text
    var allNodes = svg.selectAll("g.node")
        .data(nodes.filter(function(n) { return !n.children; }))
      .enter().append("svg:g")
        .attr("class", "node")
        .attr("id", function(d) { return "node-" + d.key; })
        .attr("parentNode", function(d) { return d.parent.name;})
        .attr("transform", function(d) { return "rotate(" + (d.x - 90) + ")translate(" + d.y + ")"; });

    allNodes.append("svg:circle")
        .attr("r", Math.min(1/Math.log10(df.length)*5, 4))
        .style("fill", function(d) { return d.color; })
        .on("mouseover", mouseover)
        .on("mouseout", mouseout)
        .on("click", mouseclick);

    allNodes.append("svg:text")
        .style("fill", function(d){ return d.color;})
        .style("font-size", function(){
          return Math.min(1/Math.log10(df.length)*15, 14)
        })
        .attr("dx", function(d) { return d.x < 180 ? 8 : -8; })
        .attr("dy", ".31em")
        .attr("text-anchor", function(d) { return d.x < 180? "start" : "end"; })
        .attr("transform", function(d) { return d.x < 180 ? null : "rotate(180)"; })
        .text(function(d) { return d.key; })

    // still will become true when Highlight clicked pathways button is clicked.
    // Once true, mouseover, mouseout, and mouseclick will be ineffective
    var still = false;

    // resets clicked selections on double click
    svg.on("dblclick", mousedbl);

    // when the mouse is held down and moved, the network will rotate
    d3.select(window)
      .on("mousemove", mousemove)
      .on("mouseup", mouseup);

    // returns the pixel coordinates of the mouse
    function mouse(e) {
      return [e.pageX - rx, e.pageY - ry];
    }

    //
    function mousedown() {
      m0 = mouse(d3.event);
      d3.event.preventDefault();
    }

    function mousemove() {
    if (m0) {
      var m1 = mouse(d3.event),
          dm = Math.atan2(cross(m0, m1), dot(m0, m1)) * 180 / Math.PI,
          rotate1 = rotate ? rotate+dm : dm+shiftRotate;

      svg.style("-webkit-transform", "translateX(" + rx + "px)translateY(" + ry + "px)rotateZ(" + rotate1 + "deg)");
    }
    }

    function mouseup() {
      if (m0) {
        var m1 = mouse(d3.event),
            dm = Math.atan2(cross(m0, m1), dot(m0, m1)) * 180 / Math.PI;

        rotate = rotate ? rotate+dm : dm+shiftRotate;
        if (rotate > 360) rotate -= 360;
        else if (rotate < 0) rotate += 360;
        m0 = null;

        svg.style("-webkit-transform", null);

        svg
            .attr("transform", "translate(" + rx + "," + ry + ")rotate(" + rotate + ")")
          .selectAll("g.node text")
            .attr("dx", function(d) { return (d.x + rotate) % 360 < 180 ? 8 : -8; })
            .attr("text-anchor", function(d) { return (d.x + rotate) % 360 < 180 ? "start" : "end"; })
            .attr("transform", function(d) { return (d.x + rotate) % 360 < 180 ? null : "rotate(180)"; });
      }
    }

    function mouseover(d) {
      if(!still){
        if(!d.clicked){
          if(clickedData.length === 0 || childrenArray.indexOf(d.name) > -1){
            setvals(d, true, false)
          }
          if(clickedData.length === 0){
            d3.selectAll(".vizText").remove()
            paintWindow(d, 1)
          }
          else if(childrenArray.indexOf(d.name) > -1){
            d3.selectAll(".vizText").remove()
            paintWindow(d, 3);
          }
        }
        else{
            setvals(d, true);
        }
      }
    }

    function mouseout(d) {
      if(!still){
        var i = clickedData.length>1 ? clickedData.length-1 : 0;
        if(!d.clicked){
          setvals(d, false);
          if(clickedData.length>=1){
            setvals(clickedData[i], true, false)
          }
        }
        else if(clickedData.length === 1){
          setvals(d, true, false)
          setvals(clickedData[i], true, false)
        }
        if(clickedData.length === 0){
          clearVizText()
        }
        else{
          d3.selectAll(".vizText").remove()
          paintWindow(d, 2)
        }
      }
    }

    function mouseclick(d){
      if(!still){
        d.clicked = !d.clicked && true;

        clickedData.push(d)

        if(d.clicked){
          removelinks()

          setvals(d, true, false)

          d3.selectAll(".vizText").remove()
          paintWindow(d, 1);

          updateChildren(d)

          childrenArray = childrenData[d.name][0]
        }
        else if(clickedData[clickedData.length-1].name === d.name){
          setvals(d, true, false)
        }
        else{
          clickedData.pop()

          updateChildren(d, true)

          setvals(d, false, false)
        }

        clickeRs = getClicker();

        Shiny.setInputValue("clickedData", clickeRs);
      }
    }

    function getClicker(){
      nConn = clickedData.length
      if(nConn===0){
        return '{}';
      }
      else if(nConn===1){
        clicker = clickedData[0]
        clickeR = '{"Name1": ["' + clicker.key + '"],' +
                  '"Node1": ["' + clicker.name + '"],' +
                  '"Parent1": ["' + clicker.parent.name + '"],' +
                  '"Connections1": ["' + clicker.imports.length + '"],' +
                  '"Confidence": ["' + clicker.Confidence + '"]}'
        return clickeR;
      }
      else{
        var clickeRs = '['
        for(conn in clickedData){
            clicker = clickedData[conn]
            if(conn < nConn-1){
              nextClicker = clickedData[parseInt(conn)+1]
              clickeR = '{"Name1": ["' + clicker.key + '"],' +
                        '"Node1": ["' + clicker.name + '"],' +
                        '"Parent1": ["' + clicker.parent.name + '"],' +
                        '"Connections1": ["' + clicker.imports.length + '"],' +
                        '"Confidence": ["' + clicker.Confidence + '"],' +
                        '"Name2": ["' + nextClicker.key + '"],' +
                        '"Node2": ["' + nextClicker.name + '"],' +
                        '"Parent2": ["' + nextClicker.parent.name + '"],' +
                        '"Connections2": ["' + nextClicker.imports.length + '"],' +
                        '"Weight": ["' + clicker.weights[clicker.imports.indexOf(nextClicker.name)] + '"],' +
                        '"Source": ["' + clicker.datasource[clicker.imports.indexOf(nextClicker.name)] + '"]},'
            }
            else{
              clickeR = '{"Name1": ["' + clicker.key + '"],' +
                        '"Node1": ["' + clicker.name + '"],' +
                        '"Parent1": ["' + clicker.parent.name + '"],' +
                        '"Connections1": ["' + clicker.imports.length + '"],' +
                        '"Confidence": ["' + clicker.Confidence + '"],' +
                        '"Name2": ["NA"], "Node2": ["NA"], "Parent2": ["NA"], "Connections2": ["NA"], "Weight": ["NA"], "Source": ["NA"]}]'
            }
            clickeRs = clickeRs + clickeR
          }
        return clickeRs;
      }
    }

    function mousedbl(){
      childrenData = {}
      childrenArray = []
      still = false

      svg.selectAll("path.link")
          .style("stroke-opacity", 0.05)

      if(clickedData.length>0){
        for(var i in clickedData){
          setvals(clickedData[i], false, false)
          clickedData[i].clicked = false
          svg.select("#node-" + clickedData[i].key)
              .style('font-weight', 'normal');
        }
        clickedData = []
      }

      svg.selectAll(".node text")
        .style("font-weight", "normal")
        .style("opacity", 1)

      svg.selectAll(".node circle").style('opacity', 1)

      svg.attr("transform",  "translate(" + rx + "," + ry + ")rotate(" + shiftRotate + ")")
      rotate = shiftRotate;
      clearVizText()

      Shiny.setInputValue("clickedData", '{}');
    }

    function clearVizText(){
      d3.selectAll(".vizText").remove()
      windowFields = ['Gene Name:', ' ',
                      'Connections:',
                      'Confidence:']
      windowText.data(windowFields)
        .enter()
          .append("svg:text")
          .attr("class", "vizText")
          .style("fill", "black")
          .attr("transform", function(d) { return "translate(0,20)"; })
          .attr("dy", function(d,i){return(20*i)})
          .attr("dx", 2)
          .text(function(d) { return d; });
    }


    function updateChildren(d, remove=false){
      childrenArray = []

      if(!remove){
        childrenData = {[d.name]: [d.imports]}
      }
      else{
        delete childrenData[d.name]
      }
    }

    function setvals(d, val, block=true, pop=8){
      if(block){
        if(svg.selectAll("path.link.target-" + d.key).classed("target") === val){
          return;
        }
      }

      svg.selectAll("path.link.target-" + d.key)
          .classed("target", val)
          .style("stroke-opacity", val*.95 + .05)
          .each(updateNodes("source", val, pop));

      svg.selectAll("path.link.source-" + d.key)
          .classed("source", val)
          .style("stroke-opacity", val*.95 + .05)
          .each(updateNodes("source", val, pop));

      svg.selectAll(".node.source text")
          .filter(function(){
            return d3.select(this).attr("dx") == 8
          })
          .attr("dx", pop*val + pop)
          .style("font-weight", "bold")

      svg.selectAll(".node.source text")
          .filter(function(){
            return d3.select(this).attr("dx") == -8
          })
          .attr("dx", -pop*val - pop)
          .style("font-weight", "bold")

      svg.selectAll(".node")
          .filter(function(){
            return d3.select(this).select(" text").attr("dx") > 8 && d3.select(this).attr("class") === "node";
          })
          .selectAll(" text")
          .attr("dx", 8)
          .style("font-weight", "normal")

      svg.selectAll(".node")
          .filter(function(){
            return d3.select(this).select(" text").attr("dx") < -8 && d3.select(this).attr("class") === "node";
          })
          .selectAll(" text")
          .attr("dx", -8)
          .style("font-weight", "normal")
    }

    function updateNodes(name, value) {
      return function(d) {
        if (value) this.parentNode.appendChild(this);

        lastclicked = clickedData[clickedData.length-1];
        nodeBold = value || lastclicked===d[name] ? 'bold' : 'normal';

        svg.select("#node-" + d[name].key)
          .classed(name, value)
      };
    }

    function removelinks(){
      for(var i = 0; i < clickedData.length-1; i++){
        clickedData[i].clicked = false

        svg.selectAll("path.link.target-" + clickedData[i].key)
          .classed('target', false)
          .style("stroke-opacity", 0.05)
          .each(updateNodes("source", false));

        svg.selectAll("path.link.source-" + clickedData[i].key)
          .classed('source', false)
          .style("stroke-opacity", 0.05)
          .each(updateNodes("target", false,));
      }
    }

    function drawConnections(){
      still = true;
      nConn = clickedData.length
      if(nConn === 0){
        still = false
        return;
      }
      else if(nConn === 1){
        svg.selectAll("path.link")
            .classed("source", false)
            .style("stroke-opacity", 0.01)

        svg.selectAll(".node text").style('opacity', 0.5)

        svg.selectAll(".node circle").style('opacity', 0.5)

        sourceName = clickedData[0].key

        svg.selectAll("path.link.source-" + sourceName)
            .classed("source", true)
            .style("stroke-opacity", 1)

        svg.selectAll(".node")
            .filter(function(){
              return d3.select(this).select(" text").attr("dx") != 8 &&
                      d3.select(this).select(" text").attr("dx") != -8 &&
                      d3.select(this).attr("class") !== "node";
            })
            .selectAll(" text")
            .style('opacity', 1)
            .style("font-weight", "bold")

        svg.selectAll(".node")
            .filter(function(){
              return d3.select(this).select(" text").attr("dx") != 8 &&
                      d3.select(this).select(" text").attr("dx") != -8 &&
                      d3.select(this).attr("class") !== "node";
            })
            .selectAll(" circle")
            .style("opacity", 1)

      }
      else{
        svg.selectAll("path.link")
            .classed("source", false)
            .style("stroke-opacity", 0.01)

        svg.selectAll(".node text")
            .style("font-weight", "normal")
            .style('opacity', 0.5)

        svg.selectAll(".node circle").style('opacity', 0.5)

        svg.selectAll(".node")
            .filter(function(){
              return d3.select(this).select(" text").attr("dx") < -8;
            })
            .selectAll(" text")
            .attr("dx", -8)

        svg.selectAll(".node")
            .filter(function(){
              return d3.select(this).select(" text").attr("dx") > 8;
            })
            .selectAll(" text")
            .attr("dx", 8)

        for(i in clickedData){
          i = parseInt(i)
          if(i != nConn-1){
            sourceName = clickedData[i].key
            targetName = clickedData[i+1].key
            svg.select("path.link.source-" + sourceName + ".target-" + targetName)
                .classed("source", true)
                .style("stroke-opacity", 1)
          }
          svg.select("#node-" + clickedData[i].key + " text")
              .attr("dx", function(d){
                if(d3.select("#node-" + clickedData[i].key + " text").attr("dx") == -8){
                  return -16;
                }
                else{
                  return 16;
                }
              })
              .style('font-weight', 'bold')
              .style('opacity', 1);

          svg.select("#node-" + clickedData[i].key + " circle")
              .style("opacity", 1)
        }
      }
    }

    function cross(a, b) {
      return a[0] * b[1] - a[1] * b[0];
    }

    function dot(a, b) {
      return a[0] * b[0] + a[1] * b[1];
    }

    function paintWindow(d, option){
      if(option === 1){
        windowFields = ['Gene Name: ',
                        d.key,
                        'Connections: ' + d.datasource.length,
                        'Confidence: ' + d.Confidence]
        windowFields = [].concat.apply([], windowFields);
        var textColor = d.color
        windowText.data(windowFields)
          .enter()
            .append("svg:text")
            .attr("class", "vizText")
            .style("fill", function(d, i){
              if(i===1){
                return textColor;
              }
            })
            .attr("transform", function(d) { return "translate(0,20)"; })
            .attr("dy", function(d, i){
              return i*20;
            })
            .attr("dx", function(d, i){
              if(i===1){
                return 10;
              }
              else{
                return 2;
              }
            })
            .text(function(d){return d;});
      }
      else if(option === 2){
        n = clickedData[clickedData.length-1]
        windowFields = ['Gene Name: ',
                        n.key,
                        'Connections: ' + n.datasource.length,
                        'Confidence: ' + n.Confidence]
        windowFields = [].concat.apply([], windowFields);
        var textColor = n.color;
        var windowL = windowFields.length;
        windowText.data(windowFields)
          .enter()
            .append("svg:text")
            .attr("class", "vizText")
            .style("fill", function(d, i){
              if(i===1){
                return textColor;
              }
            })
            .attr("transform", function(d) { return "translate(0,20)"; })
            .attr("dy", function(d, i){
              return i*20;
            })
            .attr("dx", function(d, i){
              if(i===1){
                return 10;
              }
              else{
                return 2;
              }
            })
            .text(function(d){return d;});
      }
      else{
        n = clickedData[clickedData.length-1]
        cInd = childrenArray.indexOf(d.name)
        windowFields = ['Linked Gene: ', d.key,
                        'Reference Gene: ', n.key,
                        'Connections: ' + d.weights.length,
                        'Score: ' + n.weights[cInd],
                        'Source: ' + n.datasource[cInd]];
        var linkedColor = d.color;
        var refColor = n.color;
        windowText.data(windowFields)
          .enter()
            .append("svg:text")
            .attr("class", "vizText")
            .style("fill", function(d, i){
              if(i === 1){
                return linkedColor;
              }
              else if(i === 3){
                return refColor;
              }
            })
            .attr("transform", function(d) { return "translate(0,20)"; })
            .attr("dy", function(d, i){
              return i*20;
            })
            .attr("dx", function(d, i){
              return (i>3 || i % 2 ===0) ? 2 : 10;
            })
            .text(function(d){return d;});
      }
    }

});
