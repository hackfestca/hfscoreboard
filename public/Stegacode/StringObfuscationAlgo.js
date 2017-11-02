var strConverters = [function (_process, _depth) {
						 throw new Error("Number base 10 Array");
                      },
                      function (_process, _depth) {
                    	  throw new Error("Number Base 8 Array");   	  
                      },
                      function (_process, _depth) {
                    	  throw new Error("Base64 Str");   
                      },
                      function (_process,_depth) {
                    	  throw new Error("Base16 Str"); 
                      },
                      function (_process,_depth){
                    	  throw new Error("Base8 Str"); 
                      },
                      function (_process,_depth) {
                    	  throw new Error("Base2 Str Array"); 
                      }, 
                      function (_process,_depth) {
                    	  throw new Error("Permutation Str");
                      }, 
                      function (_process,_depth) {
                    	  throw new Error("URI encode");
                      },
                      function (_process,_depth) {
                    	  throw new Error("Padding");
                      }];

function convert3Bytes(_bytesBuffer) {
	var values = [];
	
	values.push((224 & _bytesBuffer[0]) >> 5);
	values.push((28 & _bytesBuffer[0]) >> 2);
	values.push((3 & _bytesBuffer[0]) * 2 + ((128 & _bytesBuffer[1]) >> 7));
	values.push((112 & _bytesBuffer[1]) >> 4);
	values.push((14 & _bytesBuffer[1]) >> 1);
	values.push((1 & _bytesBuffer[1]) * 4 + ((192 & _bytesBuffer[2]) >> 6));		
	values.push((56 & _bytesBuffer[2]) >> 3);
	values.push(7 & _bytesBuffer[2]);
	
	return values;
}

function* getBase8Value(_payload){
	var bufValues = [];
	while(true) {
		if(_payload.length === 0 && bufValues.length === 0) {	// No more data
			break;
		} else if (_payload.length >= 3 && bufValues.length === 0) {
			bufValues = convert3Bytes(_payload);
			_payload = _payload.slice(3);
		} else if(_payload.length === 2 && bufValues.length === 0) {
			bufValues = convert3Bytes([_payload[0],_payload[1],4]).concat(convert3Bytes([4,4,4]));
			_payload = _payload.slice(2);
		} else if (bufValues.length === 0){
			bufValues = convert3Bytes([_payload[0],5,5]).concat(convert3Bytes([5,5,5]));
			_payload = _payload.slice(1);
		}
		
		yield bufValues.shift();
	}
	
	return null;
}

function encode(_ast, _payload, _options) {
	var valueGen = getBase8Value(_payload), padding = false;
	function process(_node, _depth) {
		if(_depth >= _options.depth ||
			!_node.value || typeof _node.value !== "string" || _node.value.length === 0) {	// Do nothing if its an empty string
			return _node;
		}

		// Recursive application of process performed in depth first order of the AST
		var value = valueGen.next();
		if(value.done && (_depth === 0 || !padding)) { // if no more data to encode and first level flag as padding
			padding = true;
			return strConverters[8].call(_node, process, _depth);
		} else if(value.done) {			// if no more data to encode and not first level generate random
			return strConverters[Math.floor(Math.random() * 7)].call(_node, process, _depth);
		} else {	// Encode with the appropriate value;
			return strConverters[value.value].call(_node, process, _depth);	
		}
	}
	
	estraverse.replace(_ast, {
	    leave: function (_node) {
	    	var replacement = replacers(_node);
	    	if(replacement !== null) {
	    		return replacement.call(_node, process);
	    	}
	    	
	    	return _node;
	    }
	});
}