
fn.importData <- function(MDBPATH, TABLES, DROP_VARS = c(), ORDER_BY = c(), PWD = "") {
  # Function connects to any Access database, fetches one or multiple tables and loads them
  # into R's global environment.
  #
  # Args:
  #   MDBPATH {character}: absolute path specifying location of database.
  #   TABLES {vector}: vector of table names {character} to be loaded from Access.
  #   DROP_VARS {vector}: vector of variables to exclude. Empty vector by default.
  #   ORDER_BY {vector}: vector of variables which determine howto sort table. Empty vector by default.
  #   PWD {character}: password string required to access protected database. Empty vector by default.
  #
  # Returns:
  #   {none}

  # NOTE: Make sure you are using R 32-bit, since the 64-bit version is not compatible with RODBC.

  # Import package
  library(RODBC)

  # Set up Driver
  DRIVERINFO <- "Driver={Microsoft Access Driver (*.mdb, *.accdb)};"

  # Check if password is required
  if (PWD != "") {
    PWD <- paste0("; pwd=", PWD, ";")
  }

  # Concatenate full path to database
  PATH <- paste0(DRIVERINFO, "DBQ=", MDBPATH, PWD)
  # Connect to database
  channel <- odbcDriverConnect(PATH)

  # Iterate through list of tables
  for (tbl in TABLES) {

    # For some reasons, R doesn't seem to like it when the SELECT * command is
    # excecuted and might cause unexpected errors. To prevent the program from
    # crashing, we will first retrieve the columns names, and then execute the SQL
    # command giving it specific variables.

    # Retrieve all variable names from table tbl
    tbl_vars <- sqlColumns(channel, tbl)["COLUMN_NAME"]

    # Exclude variables based on input parameters
    tbl_vars <- subset(tbl_vars, !(tbl_vars$COLUMN_NAME %in% DROP_VARS))

    # Add brackets to each variable (ie. [variable]) to maintain ACCESS syntax
    tbl_vars$COLUMN_NAME <- paste0("[", tbl_vars$COLUMN_NAME, "]")

    # Transform dataframe column into string separated by comma
    cols <- paste0(tbl_vars[1:nrow(tbl_vars),], collapse = ",")

    # Create ORDER BY string
    if (length(ORDER_BY) > 0) {
      order <- paste0("ORDER BY", paste0(paste0("[", ORDER_BY, "]"), collapse = ", "))
    } else {
      order <- ""
    }

    # Extract table of interest as dataframe
    df <- sqlQuery(channel,
      paste0("SELECT ", cols,
       " FROM [", tbl,
       "]", order, ";"),
      stringsAsFactors = FALSE)

    # Replace dash with underscore
    new_tbl_name <- gsub("-", "_", tbl)

    # Assign dataframe to environment
      assign(new_tbl_name, df, envir = .GlobalEnv)

  }

  # Clear connection
  close(channel)
  rm(channel)

}
