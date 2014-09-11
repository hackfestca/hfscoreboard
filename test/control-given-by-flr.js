// require JQUERY
//
// Create a workflow :
// <div class="workflow">
// </div>
// 
// Add a step to the workflow :
// <div class="step">
//		step content
// </div>
//
// First button :
// <input type="button" class="first-button">
//
// Prev button :
// <input type="button" class="prev-button">
//
// Next button :
// <input type="button" class="prev-button">
//
// Last button :
// <input type="button" class="last-button">

$(function() {
	var step = 1;
	if($(".workflow > .step").length === 0)
		return;
		
	$(".workflow .step").hide();
	$(".workflow .step:nth-child(1)").show();

	handleProgressBar = function() {
		var progress = step / $(".workflow > .step").length * 100;
		$(".workflow .progress-bar").width(progress + "%");
		$(".workflow .progress-bar").text(progress + "%");
	};
	
	handleButton = function() {
		if(step === 1)
			$(".workflow .prev-button").addClass("disabled");
		else
			$(".workflow .prev-button").removeClass("disabled");
			
		if(step === $(".workflow .step").length)
			$(".workflow .next-button").addClass("disabled");
		else
			$(".workflow .next-button").removeClass("disabled");
	};
	
	$(".workflow .first-button").click(function() {
		if(step === 1)
			return;
		
		$(".workflow .step:nth-child(" + step + ")").hide();
		step = 1;
		$(".workflow .step:nth-child(1)").show();
		
		handleButton();
		handleProgressBar();
	});
	
	$(".workflow .prev-button").click(function() {
		if(step === 1)
			return;
		
		$(".workflow .step:nth-child(" + step + ")").hide();
		step--;
		$(".workflow .step:nth-child(" + step + ")").show();
		
		handleButton();
		handleProgressBar();
	});
	
	$(".workflow .next-button").click(function() {
		if(step === $(".workflow .step").length)
			return;
		
		$(".workflow .step:nth-child(" + step + ")").hide();
		step++;
		$(".workflow .step:nth-child(" + step + ")").show();
		
		handleButton();
		handleProgressBar();
	});
	
	$(".workflow .last-button").click(function() {
		if(step === $(".workflow > .step").length)
			return;
		
		$(".workflow .step:nth-child(" + step + ")").hide();
		step = $(".workflow > .step").length;
		$(".workflow .step:nth-child(" + step + ")").show();
		
		handleButton();
		handleProgressBar();
	});
	
	handleButton();
	handleProgressBar();
});