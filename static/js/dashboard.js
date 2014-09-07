
google.load("visualization", "1", {packages:["corechart"]});
function drawChart(data_array) {

    var data = google.visualization.arrayToDataTable(data_array);
    
    var options = {
	title: 'Score',
	backgroundColor: '#000000',
	baselineColor: '#FFFFFF',
	hAxis: { textStyle: { color: '#FFFFFF' } },
	vAxis: { textStyle: { color: '#FFFFFF' } },
	legend: { textStyle: { color: '#FFFFFF' } },
	explorer: { actions: ['dragToPan', 'rightClickToReset'] },
	titleTextStyle: { color: '#FFFFFF' }
    };

    var chart = new google.visualization.LineChart(document.getElementById('chart_div'));
    
    chart.draw(data, options);
}
