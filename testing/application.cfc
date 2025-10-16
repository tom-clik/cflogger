component {
	this.name = "logger.testing";
	this.clientmanagement="Yes";
	this.clientstorage="cookie";
	this.SessionManagement="Yes";
	
	void function onError(e) {
		
		param request.prc = {};

		local.args = {
			e=arguments.e,
			debug=1,
			isAjaxRequest=request.prc.isAjaxRequest ? : 0 
		};

		try {
			new cferrorHandler.errorHandler(argumentCollection=local.args);
		}
		catch (any e2) {
			throw(object=arguments.e);
		}
		
	}

}
