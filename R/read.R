#' Read databases from config
#'
#' @param file Path to configuration file.
#' @param ... Paths to additional configuration files to merge into `file`.
#' @return A named list of connectable databases specified in the configuration file.
#' @export
read_databases <- function(file, ...) {
  validator <- create_validator()
  config <- load_config(file, validator)
  for (other_file in c(...)) {
    other_config <- load_config(other_file, validator)
    config <- merge_config(config, other_config)
  }
  validate_config(config, validator)
  databases <- purrr::pluck(config, "database", .default = named_list())
  templates <- purrr::pluck(config, "template", .default = named_list())
  purrr::imap(databases, parse_database, templates)
}

read_config <- function(file) {
  out <- RcppTOML::parseTOML(input = file, fromFile = TRUE, escape = FALSE)
  if (rlang::is_empty(out)) {
    out <- named_list()
  }
  if (rlang::has_name(out, "template")) {
    out$template <- purrr::imap(out$template, function(template, name) {
      purrr::map(template, function(template) {
        attr(template, "template") <- name
        template
      })
    })
  }
  out
}

validate_config <- function(config, validator = create_validator()) {
  json <- jsonlite::toJSON(config, auto_unbox = TRUE)
  validator(json = json, error = TRUE, greedy = TRUE)
  invisible(config) }

create_validator <- function() {
  jsonvalidate::json_validator(
    schema = fs::path_package("dbiconf", "schema/schema.json"),
    engine = "ajv"
  )
}

load_config <- function(path, validator = create_validator()) {
  out <- read_config(path)
  validate_config(out, validator)
  out
}

merge_config <- function(config, other) {
  database <- merge_list(
    purrr::pluck(config, "database", .default = named_list()),
    purrr::pluck(other, "database", .default = named_list())
  )

  template <- merge_list(
    purrr::pluck(config, "template", .default = named_list()),
    purrr::pluck(other, "template", .default = named_list())
  )

  list(database = database, template = template)
}

merge_list <- function(x, y) {
  purrr::iwalk(y, function(item, name) {
    if (rlang::has_name(x, name)) {
      item <- rlang::dots_list(!!!x[[name]], !!!item, .homonyms = "last")
    }
    x[[name]] <<- item
  })
  x
}
