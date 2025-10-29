/**
 * # Logger component
 *
 * Add log entry to either database or request.logger 
 *
 * ## Usage
 *
 * Instantiate and either use directly or pass to components that
 * utilise the logger pattern.
 *
 * If database mode is on, will log to database, otherwise will create
 * a request variable that can be output at the end of the request.
 *
 * use log() to log a request. Warnings and errors are always logged. 
 * Information is logged if in debug mode (see init)
 *
 * use viewLog() to view all log entires for a request. 
 *
 * Use catgeory when logging or viewing to filter results.
 *
 * ## Logger Pattern
 *
 * To implement a logger, components should have a method that checks for the existence of 
 * a logging component in the this scope, and calls it if defined.
 *
 * ```
 *	private void function logger(required text, type="I", category="") output=false {
 *		if (StructKeyExists(this,"loggerObj")) {
 *			this.loggerObj.log(argumentCollection = arguments);
 *		}
 *	}
 *	```
 *  The component can be added by injection when needed (`yourObj.loggerObj = new logger.logger()`)
 * 
 */
component logger {
	/**
	 * Pseduo constructor
	 * 
	 * @debug   Log/ignore information level entries
	 * @db      Use database
	 * @dsn     Datasource for database logging
	 */
	public logger function init (
		boolean debug=false,
		boolean db=false,
		string  dsn
		)  output=false {

		variables.debug = arguments.debug;
		variables.db = arguments.db;
		if ( variables.db ) {
			if ( ! StructKeyExists(arguments, "dsn") ) {
				throw( "No dsn supplied with db log mode" );
			}
			else {
				variables.dsn = arguments.dsn;
			}
		}

		return this;

	}
	/**
	 * Add to log
	 * 
	 * @text     text to log
	 * @type    Information|Error|Warning (can use single letter)
	 * @category Optional category
	 */
	void function log(required text, type="I", category="") output=false {
		
		//  log all errors and warnings 
		switch ( arguments.type ) {
			case  "warning": case "w": 
				local.log = 1;
				break;
			case "error": case "e":
				local.log = 1;
				break;
			case "information": case "i":
				local.log = variables.debug;
				break;
			default:
				throw("Unknown log type #arguments.type #");
				break;
		}

		if (local.log) {
			if (! request.keyExists("logrunID") ) {
				request.logrunID = createUUID();
			}

			local.logentry = {
				"logtype" = UCASE(Left(arguments.type,1)),
				"category" = arguments.category,
				"log_text" = Left(arguments.text,8000),
				"server_name" = cgi.server_name,
				"request_id" = request.logrunID,
				"tickCount" = getTickCount()
			};
			if (variables.db) {
				writeDBLog(local.logentry);
			}
			else {
				if (! request.keyExists("logger") ) {
					request.logger = [];
				}
				local.logentry["logtime"] = now();
				request.logger.append(local.logentry);
			}

		}

	}

	static private void function writeDBLog(required struct logentry) output=false {

		local.sql = "
			INSERT INTO  cflog (
	             logtype
	           , cflog_category
	           , log_text
	           , server_name
	           , request_id
	           )
	     	VALUES	(
	     		  :logtype
	           ,  :cflog_category
	           ,  :log_text
	           ,  :server_name
	           ,  :request_id
	     	)
		";
		local.params = {
			"logtype":{value=arguments.logentry.logtype, cfsqltype="cf_sql_varchar"},
			"cflog_category":{value=arguments.logentry.category, null = arguments.logentry.category eq "" , cfsqltype="cf_sql_varchar"},
			"log_text":{value=arguments.logentry.log_text, cfsqltype="cf_sql_varchar"},
			"server_name":{value=arguments.logentry.server_name, cfsqltype="cf_sql_varchar"},
			"request_id":{value=arguments.logentry.request_id, cfsqltype="cf_sql_varchar"},
		};
		
		queryExecute( local.sql, local.params, { datasource=variables.dsn } );
		
	}

	private array function getDBLog(required string logrunID) output=false {

		local.sql = "
			SELECT
				 logtime 
			   , logtype
	           , cflog_category as category
	           , log_text

			FROM    cflog 
	        WHERE   request_id = :request_id
	        ORDER BY logtime_exact
	    ";
		local.params = {
			"request_id":{value=arguments.logrunID, sqltype="varchar"},
		};
		
		return queryExecute( local.sql, local.params, { datasource=variables.dsn, returnType="array" } );
		
	}

	/**
	 * Output log entries for current request filtered by category
	 */
	public void function viewLog(category="") {
		
		local.log = getLog(category="");

		if ( ! local.log.len() ) {
			writeOutput("<p>No log entries for this request</p>");
		} 
		else {
			
			writeOutput( logHTML(log=local.log,db=variables.db,category=arguments.category) );

		}

	}

	/**
	 * Return the raw log array
	 */
	public array function getLog() {
	
		if ( !StructKeyExists(request,"logrunID") ) {
			local.log = [];
		} 
		else {
			
			if ( variables.db ) {
				local.log = getDBLog(request.logrunID);
			}
			else {
				local.log = request.logger;
			}

		}

		return local.log;

	}
	/**
	 * Generate HTML for a log view filtered by category. 
	 */
	static private function logHTML(required array log, boolean db=0, string category="") {

		writeOutput("<table class=""info"" border=""1"" cellpadding=""2"" cellspacing=""0"" style=""background-color: white; color: black;"">
			<tr>
				<th>Time</th>");
		if ( !arguments.db ) {	
			WriteOutput("<th>Tick count</th>");	
			local.start_timer = arguments.log[1].tickCount;
		}	

		writeOutput("
				<th>Type</th>
				<th>Cat</th>
				<th>Text</th>
			</tr>");

		for (local.logentry in arguments.log) {
			if (arguments.category eq "" OR ListFindNocase(arguments.category, local.logentry.category)) {
				writeOutput("<tr>");
				writeOutput("	<td>#local.logentry.logtime#</td>");
				if ( !arguments.db ) {	

					WriteOutput("<td>#local.logentry.tickCount- local.start_timer#</td>");
					local.start_timer = local.logentry.tickCount;
				}
				writeOutput("	<td>#local.logentry.logtype#</td>");
				writeOutput("	<td>#local.logentry.category#</td>");
				writeOutput("	<td style=""padding-left:5px; text-align:left;"">#local.logentry.log_text#</td>");
				writeOutput("</tr>");
			}
		}

		writeOutput("</table>");

	}

}