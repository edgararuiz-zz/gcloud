
<!-- README.md is generated from README.Rmd. Please edit that file -->

# gcloud

This package provides a light wrapper to Google’s *gcloud* CLI. It
currently focuses on automating the creation and setup of VM instances.

## Installation

The Google SDK needs to be installed prior use of this package:
<https://cloud.google.com/sdk/install>

``` r
devtools::install_github("edgararuiz/gcloud")
```

## Basics

Use `gcloud_shell()` to run standard commands against your current
Google Cloud project. The function automatically prefixes *gcloud* to
the command.

``` r
library(gcloud)

gcloud_shell("compute instances list")
#> [1] "NAME          ZONE           MACHINE_TYPE   PREEMPTIBLE  INTERNAL_IP    EXTERNAL_IP     STATUS" 
#> [2] "r-snyhepwjps  us-central1-a  n1-standard-8               10.128.15.218  35.194.29.200   RUNNING"
#> [3] "r-vzrumozhqo  us-central1-a  n1-standard-8               10.128.15.219  35.202.122.184  RUNNING"
```

`gcloud_to_tibble()` parses some of the CLI’s output into tibbles. It
automatically detects the location and length of each column.

``` r
gcloud_to_tibble("compute instances list")
#> # A tibble: 2 x 7
#>   NAME    ZONE     MACHINE_TYPE  PREEMPTIBLE INTERNAL_IP EXTERNAL_IP STATUS
#>   <chr>   <chr>    <chr>         <chr>       <chr>       <chr>       <chr> 
#> 1 r-snyh~ us-cent~ n1-standard-8 ""          10.128.15.~ 35.194.29.~ RUNNI~
#> 2 r-vzru~ us-cent~ n1-standard-8 ""          10.128.15.~ 35.202.122~ RUNNI~
```

Higher level wrappers are available as well, such as
`gcloud_instances()`, `gcloud_images()` and `gcloud_machine_types()`.

``` r
gcloud_instances()
#> # A tibble: 2 x 7
#>   NAME    ZONE     MACHINE_TYPE  PREEMPTIBLE INTERNAL_IP EXTERNAL_IP STATUS
#>   <chr>   <chr>    <chr>         <chr>       <chr>       <chr>       <chr> 
#> 1 r-snyh~ us-cent~ n1-standard-8 ""          10.128.15.~ 35.194.29.~ RUNNI~
#> 2 r-vzru~ us-cent~ n1-standard-8 ""          10.128.15.~ 35.202.122~ RUNNI~
```

To see the current configuration settings for your user use
`gcloud_config()`.

``` r
gcloud_config()
#> $region
#> [1] "us-central1"
#> 
#> $zone
#> [1] "us-central1-a"
#> 
#> $account
#> [1] "edgar@rstudio.com"
#> 
#> $disable_usage_reporting
#> [1] "True"
#> 
#> $project
#> [1] "rstudio-job-launcher"
```

## Server creation and configuration

A new server VM instance can be created using `gcloud_new_instance()`.
The function contains enough default arguments that allows the creation
of a 8 CPU server with Ubuntu 18.04 by just calling the function.

``` r
new_server <- gcloud_new_instance()
```

Once created, it is easy to interact with the new server using

``` r
gcloud_run("ls /home", server_name = new_server)
#> [1] "edgar"   "rstudio" "ubuntu"
```

Another way to interact and configure the server is to copy and run a
bash file. This package comes with an example shell file.

``` r
script <- system.file("shell/revdep.sh", package = "gcloud")

head(readLines(script, encoding = "UTF-8"), 12)
#>  [1] "#!/bin/bash"                                                                            
#>  [2] "RSTUDIO=\"rstudio-server-1.2.1293-amd64.deb\""                                          
#>  [3] "RVERSION=\"3.5.2\""                                                                     
#>  [4] ""                                                                                       
#>  [5] "# ------------ Updating sources and packages ------------------------"                  
#>  [6] "add-apt-repository \"deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) universe\""
#>  [7] "sleep 20"                                                                               
#>  [8] "apt-get -y update"                                                                      
#>  [9] "sleep 20"                                                                               
#> [10] "# -------------------- Linux deps -----------------------------------"                  
#> [11] "apt-get -y install gdebi rrdtool wget libssl-dev libcurl4-gnutls-dev libxml2-dev git"   
#> [12] "# ------------------------- Java -----------------------------------"
```

The `revdep.sh` shell file will do the following:

  - Installs Linux dependencies, including Java
  - Install the preview version of RStudio Server Open Source
  - Builds R from source
  - Creates a user named `rstudio` and sets the password to `rstudio`
  - Pre installs `devtools` and `revdepcheck`

Use `gcloud_sh_run()` to run the shell file. It will copy and execute
the script for you.

``` r
gcloud_sh_run(script, server_name = new_server)
```

## Full example

``` r
repo <- "edgararuiz/modeldb"
# Create a new instance
new_server <- gcloud_new_instance()
Sys.sleep(30)
# Copy and run the shell script
gcloud_sh_run(
  system.file("shell/revdep.sh", package = "gcloud"), 
  server_name = new_server)
# Clone the repo, under the rstudio user
gcloud_run(
  paste0("git clone https://github.com/", repo,".git"), 
  new_server, 
  "rstudio")
# Open the RStudio port access
gcloud_shell(
  "compute firewall-rules create rstudio --rules tcp:8787 --action allow"
  )
# Get the instance list in order to get the external IP
instances <- gcloud_instances()
ext_ip <- instances$EXTERNAL_IP[instances$NAME == new_server]
# Automatically navigate to the RStudio UI
browseURL(paste0("http://", ext_ip, ":8787")) 
```
