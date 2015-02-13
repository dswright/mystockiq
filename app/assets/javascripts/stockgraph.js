function resizeChart() {
  var height = $("#stock-div").width()/3+30;
  $("#stock-div").css("height", height);
  $(".stockgraph-container1").css("height", height+10);
};

//Global variables 
var graph;
var chart1;
var currentRange;
var rangeHash = {};

$(document).ready(function () {
  resizeChart();
  $(window).bind("orientationchange resize", resizeChart);

  seriesVar = [
    {
      name : gon.ticker_symbol,
      dataGrouping: {
        enabled: false
      }
    }, 
    {
      name : "prediction",
      lineWidth : 0,
      marker : {
        enabled : true,
        radius : 4
      },
    },
    {
      name: "dateseries",
      lineWidth : 1,
      dataGrouping: {
        enabled: false
      }
    },
    {
      name:"myprediction",
      marker : {
        enabled : true,
        radius : 4,
        color: "#DC143C"
      }
    }
  ];

  chart1 = new Highcharts.StockChart({
    chart: {
      renderTo: 'stock-div'
    },
    rangeSelector : {
      enabled: false
    },
    scrollbar: {
      enabled: false
    },
    navigator: {
      enabled: false
    },
    xAxis: {
      minRange: 3600 * 1000
    },
    series: seriesVar
  });


  var apiUrl = "/stocks/" + gon.ticker_symbol + ".json";
  chart1.showLoading('Loading data from server');
  $.getJSON(apiUrl, function (data) {

    graph = data

    chart1.series[0].setData(data["daily_prices"]);
    chart1.series[1].setData(data["predictions"]);
    chart1.series[2].setData(data["daily_forward_prices"]);
    chart1.series[3].setData(data["my_prediction"]);
    chart1.hideLoading();

    //create the range hash...


    //note that by adding the my_prediction here, it will fall under the limited array filter.
    graphSettings = {intradayPrices: data["intraday_prices"], dailyPrices:data["daily_prices"], predictions:data["predictions"].concat(data["my_prediction"])};
    rangeHash = new StockGraphButtons(graphSettings);

    chart1.yAxis[0].setExtremes(rangeHash["1m"]["yMin"], rangeHash["1m"]["yMax"]);
    chart1.xAxis[0].setExtremes(rangeHash["1m"]["xMin"], rangeHash["1m"]["xMax"]);

    currentRange = {rangeHash:rangeHash["1m"],buttonType:"1m"};
  });


  function getRanges1() {
    //the trick is that the graph ranges has to be defined... 
    //replace these with the graph["ranges"]["3m"] variable, ect.. maybe pass that variable in through the function.
    buttonType = $(this).data("button-type");
    ranges = rangeHash[buttonType];


    //originally i wanted to change the frequency with which the data arrays are reset, but it doesn't seem to matter.
    if (buttonType == "1d" || buttonType == "5d") {
      chart1.series[2].setData(graph["intraday_forward_prices"]);
      chart1.series[0].setData(graph["intraday_prices"]);
    }
    else { //current range is not one of these, load the dily prices.
      chart1.series[2].setData(graph["daily_forward_prices"]);
      chart1.series[0].setData(graph["daily_prices"]);
    }

    chart1.yAxis[0].setExtremes(ranges["yMin"], ranges["yMax"]);
    chart1.xAxis[0].setExtremes(ranges["xMin"], ranges["xMax"]);

    currentRange = {rangeHash:rangeHash[buttonType], buttonType:buttonType};
    
    //window.alert(range_min + range_max)
  };

  function predictionXMax(endTime){
    return endTime+(endTime-currentRange["rangeHash"]["xMin"])*0.05;
  };
  function predictionYMax(endPrice){
    return endPrice+(endPrice-currentRange["rangeHash"]["yMin"])*0.1;
  };
  function predictionYMin(endPrice){
    return endPrice-(endPrice-currentRange["rangeHash"]["yMin"])*0.1;
  };

  //when a prediction is input, the graph ranges must be updated with new y max and mins so the button ranges include that
  //prediction.
  function updateRanges(endTime, endPrice){
    for (var value in rangeHash) {
      if (endPrice <= rangeHash[value]["yMin"] && endTime <= rangeHash[value]["xMax"]) {
        rangeHash[value]["yMin"] = predictionYMin(endPrice);
      }
      if (endPrice >= rangeHash[value]["yMax"] && endTime <= rangeHash[value]["xMax"]) {
        rangeHash[value]["yMax"] = predictionYMax(endPrice);
      }
    };
  };
  
  //window.function has the affect of setting the function as a global function, and its available in the ajax function.
  //updatePredictions adjsuts the graph ranges to show a prediction when it is put onto the graph.
  window.updatePredictions = function(endTime, endPrice) {
    chart1.series[3].setData([[endTime, endPrice]]);

    if (endTime > currentRange["rangeHash"]["xMax"]) {
      chart1.series[2].setData(graph["daily_forward_prices"]);
      chart1.series[0].setData(graph["daily_prices"]);
      chart1.xAxis[0].setExtremes(rangeHash["1m"]["xMin"], predictionXMax(endTime)); //set to the 1 month min range by default. change this later.
      chart1.yAxis[0].setExtremes(rangeHash["1m"]["yMin"], rangeHash["1m"]["yMax"]);
      current_range = rangeHash["1m"]
    }
    if (endPrice >= currentRange["rangeHash"]["yMax"]) {
      chart1.yAxis[0].setExtremes(currentRange["rangeHash"]["yMin"], predictionYMax(endPrice));
    }
    if (endPrice <= currentRange["rangeHash"]["yMin"]) {
      chart1.yAxis[0].setExtremes(predictionYMin(endPrice), currentRange["rangeHash"]["yMax"]);
    }

    updateRanges(endTime, endPrice);
  };

  window.removePrediction = function() {
    chart1.series[3].setData([null, null]);
    //reset the ranges on the buttons to be the original range amounts after the prediction is removed.
    var graphSettings = {intradayPrices: graph["intraday_prices"], dailyPrices:graph["daily_prices"], predictions:graph["predictions"]};
    rangeHash = new StockGraphButtons(graphSettings); //recreate the original ranges based on the data arrays.
    
    var buttonType = currentRange["buttonType"];
    chart1.yAxis[0].setExtremes(rangeHash[buttonType]["yMin"], rangeHash[buttonType]["yMax"]); //reset the ranges to the new maxes without the prediction.
    chart1.xAxis[0].setExtremes(rangeHash[buttonType]["xMin"], rangeHash[buttonType]["xMax"]);

    currentRange = {rangeHash:rangeHash[buttonType],buttonType:buttonType}; //reset the current range based on the new range hash.
  };

  //$("button[data-x-range-min]").click(get_ranges);
  $("button[data-button-type]").click(getRanges1);
  //remove branding logo that says 'highcarts'
  $("text").remove( ":contains('Highcharts.com')" );
});





