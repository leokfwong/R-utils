fn.initializeConstants <- function() {

  # Function initializes and loads constants into global environment so that they can be used
  # by other functions. For some projects, there might be a large amount of constant
  # variables we might want to compartmentalize. This leverages the fact that variables
  # initialize within this function can be accessed using ls(), which we can then assign
  # to the global environment for usage outside of this function.
  #
  # args:
  #   none
  #
  # return:
  #   none

  # Initialize by constants 
  BY_CPV <- c("centre_id", "patient_id", "visit")
  BY_CP <- c("centre_id", "patient_id")
  TIMEORIGIN <- "1970-01-01"

  # Iterate through all items in current environment
  for (const in ls()) {

    # Assign to global environment
    assign(const, get(const), envir = .GlobalEnv)

  }

}

fn.importData <- function(MDBPATH, TABLES, DROP_VARS = c(), ORDER_BY = c(), PWD = "") {
  # Function connects to any Access database, fetches one or multiple tables and loads them
  # into R's global environment.
  #
  # args:
  #   MDBPATH {character}: absolute path specifying location of database.
  #   TABLES {vector}: vector of table names {character} to be loaded from Access.
  #   DROP_VARS {vector}: vector of variables to exclude. Empty vector by default.
  #   ORDER_BY {vector}: vector of variables which determine howto sort table. Empty vector by default.
  #   PWD {character}: password string required to access protected database. Empty vector by default.
  #
  # return:
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

fn.formatDates <- function() {

  # Function iterates through all dataframes in global environment and converts
  # all POSIXct, POSIXt values into "Date" format.
  #
  # args: {none}
  #
  # return: {none}

  # Iterate through objects in global environment
  for (obj in ls(envir = .GlobalEnv)) {

    # If object is a dataframe
    if (class(get(obj)) == "data.frame") {

      # Get the dataframe
      df <- get(obj)

      # Iterate through every variable within dataframe
      for (field in names(df)) {

        # Find variables that are in POSIXct, POSIXt format
        if (all(class(df[[field]]) == c("POSIXct", "POSIXt"))) {

          print(paste0("Converting ", field, " from ", obj, " to date format."))

          # Convert variable to "Date"
          df[[field]] <- as.Date(df[[field]])

          # Fix obvious typos in dates
          df[[field]] <- fn.fixObviousInvalidDates(df[[field]])

          # Assign obj to global environment
          assign(obj, df, envir = .GlobalEnv)

        }
      }
    }
  }
}

fn.sortDataFrame <- function(df, order_by, ascend = TRUE) {
  # Function sorts the rows of a dataframe in a specific order based on an input
  # vector of variable names. 
  #
  # args:
  #   df {dataframe} - dataframe to be sorted
  #   order_by {vector} - vector containing the variables to order by
  #                       (ie. c("unique_id", "last_name", "first_name"))
  #
  # return:
  #   df {dataframe} - sorted dataframe

  # TODO: Implement custom sorting for each variable:
  # Demographics[order(-rank(Demographics$centre_id), Demographics$patient_id),]
  # The reason we need rank is that non-numeric values cannot be reversed using -()

  # A) Concatenate string to order dataframe
  # Initialize empty string
  str <- ""

  # Iterate through variables and concatenate to string
  for (itm in order_by) {

    str <- paste0(str, "df$", itm, ", ")

  }

  # Trim whitespace and remove last comma
  str <- trimws(str)
  str <- substr(str, 1, nchar(str) - 1)

  # Assemble entire command into string
  if (ascend) {
    str <- paste0("df[order(", str, "),]")
  } else {
    str <- paste0("df[order(", str, ", decreasing = TRUE),]")
  }

  # Evaluate string (order)
  df <- eval(parse(text = str))

  # Return ordered dataframe
  return(df)

}