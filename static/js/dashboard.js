
google.load("visualization", "1", {packages:["corechart", "controls"]});
function drawChart(data_array) {

    var data = google.visualization.arrayToDataTable(data_array);

    var options = {
	title: 'Score',
	backgroundColor: '#000000',
	baselineColor: '#FFFFFF',
	hAxis: { textStyle: { color: '#FFFFFF' } },
	vAxis: { textStyle: { color: '#FFFFFF' } },
	legend: { textStyle: { color: '#FFFFFF' } },
	titleTextStyle: { color: '#FFFFFF' }
    };

    var chart = new google.visualization.ChartWrapper({
	'chartType': 'LineChart',
	'containerId': 'chart_div',
	'options': options,
	'dataTable': data
    }); 

    chart.draw();
}
