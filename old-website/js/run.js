$(function(){

	var url = "https://cg9uao669h.execute-api.us-west-2.amazonaws.com/dev/runs/5";
	$.get(url, function(runs) {
		console.log(runs);
		for (var run in runs) {
			var url = runs[run]['embed_url']['S'];
			var title = runs[run]['name']['S'];
			$("#runs").append(`<div class='run'><h1>${title}</h1><iframe height='405' width='590'
				frameborder='0' allowtransparency='true' scrolling='no'
				 src='${url}'></iframe></div>`);
		}
	});
	
})