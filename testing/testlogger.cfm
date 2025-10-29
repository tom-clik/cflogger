<cfscript>
for (debug in [0,1]) {
	for (db in [0,1]) {
		WriteOutput("<h2>Debug: #debug#, DB: #db#</h2>")
		StructDelete(request,"logrunID");
		StructDelete(request,"logger");

		logger = new logger.logger(debug=debug,db=db,dsn="clikpic");

		logger.log("testing error");

		logger.log("warning error","w","interesting");


		logger.log("error error","e");

		logger.viewLog();
		logger.viewLog("interesting");
	}
}
</cfscript>