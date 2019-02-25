#' @import rlang
#' @importFrom purrr map
#' @importFrom purrr walk
#' @importFrom purrr map_chr
#' @importFrom purrr transpose
#' @importFrom purrr map_lgl
#' @keywords internal
utils::globalVariables(c("."))

random_name <- function(n = 10, prefix = "r-") {
  paste0(
    prefix,
    paste0(sample(letters, n, replace = TRUE), collapse = "")
  )
}

#' @export
gcloud_shell <- function(x) {
  try(system(paste0("gcloud ", x), intern = TRUE))
}

#' @export
gcloud_to_tibble <- function(x) {
  ins <- gcloud_shell(x)
  header <- ins[[1]]
  header_l <- map_chr(
    seq_len(nchar(header)),
    ~ {
      l1 <- substr(header, .x - 1, .x - 1)
      l2 <- substr(header, .x, .x)
      l1 == " " & l2 != " "
    }
  )
  pos1 <- c(1, which(as.logical(header_l)))
  pos2 <- c(which(as.logical(header_l)) - 1, nchar(header) + 1)
  pos_mapped <- map(
    ins,
    ~ {
      y <- .x
      map(seq_along(pos1), ~ trimws(substr(y, pos1[[.x]], pos2[[.x]])))
    }
  )
  t1 <- transpose(pos_mapped[2:length(ins)])
  t1 <- map(t1, ~ as.character(.x))
  t1 <- set_names(t1, flatten(pos_mapped[1]))
  dplyr::as_tibble(t1)
}

#' @export
gcloud_instances <- function(...) gcloud_to_tibble("compute instances list")

#' @export
gcloud_images <- function(...) gcloud_to_tibble("compute images list")

#' @export
get_machine_types <- function(project = gcloud_config()$project, ...) {
  res <- gcloud_to_tibble(
    paste0("compute machine-types list --project ", project)
  )
  res$MEMORY_GB <- as.numeric(res$MEMORY_GB)
  res$CPUS <- as.numeric(res$CPUS)
  res
}

#' @export
gcloud_config <- function(...) {
  configs <- gcloud_shell("config list")
  x <- map(configs, ~ strsplit(.x, " = ")[1])
  x <- map(x, ~ {
    if (length(.x[[1]]) == 2) {
      list(
        name = .x[[1]][1],
        val = .x[[1]][2]
      )
    }
  })
  x <- x[!map_lgl(x, is.null)]
  xn <- map_chr(x, ~ .x$name)
  xv <- map(x, ~ .x$val)
  set_names(xv, xn)
}

#' @export
gcloud_new_instance <- function(server_name = random_name(),
                                project = gcloud_config()$project,
                                zone = gcloud_config()$zone,
                                machine_type = "n1-standard-8",
                                boot_disk_size = 40,
                                image_project = "ubuntu-os-cloud",
                                image_family = "ubuntu-1804-lts", ...) {
  cmd <- c(
    "compute instances create", server_name,
    "--project", project,
    "--zone", zone,
    "--machine-type", machine_type,
    "--boot-disk-size", boot_disk_size,
    "--image-project", image_project,
    "--image-family", image_family
  )
  gcloud_shell(paste0(cmd, collapse = " "))
  server_name
}

#' @export
gcloud_run <- function(command, server_name, user_name = "root") {
  cmd <- c(
    "compute ssh ", user_name, "@", server_name,
    " --command=\"", paste0(command, collapse = " "), "\""
  )
  cmd <- paste0(cmd, collapse = "")
  gcloud_shell(cmd)
}

#' @export
gcloud_copy_to <- function(source, destination, server_name) {
  gcloud_shell(
    paste0("compute scp ", source, " ", server_name, ":", destination)
  )
}

#' @export
gcloud_sh_run <- function(source, destination = "/tmp", server_name) {
  source_file <- basename(source)
  dest_file <- file.path(destination, source_file)
  gcloud_copy_to(source, destination, server_name)
  gcloud_run(paste0("sed -i 's^/\\r^/^/' ", dest_file), server_name)
  gcloud_run(paste0("sudo sh ", dest_file), server_name)
}
