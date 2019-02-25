#!/bin/bash
RSTUDIO="rstudio-server-1.2.1293-amd64.deb"
RVERSION="3.5.2"

# ------------ Updating sources and packages ------------------------
add-apt-repository "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) universe"
sleep 20
apt-get -y update
sleep 20
# -------------------- Linux deps -----------------------------------
apt-get -y install gdebi rrdtool wget libssl-dev libcurl4-gnutls-dev libxml2-dev git
# ------------------------- Java -----------------------------------
apt-get -y install software-properties-common
apt-add-repository ppa:webupd8team/java
echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections
apt-get update
apt-get -y install oracle-java8-installer
apt-get -y install oracle-java8-set-default
# ----------------------- RStudio ------------------------------------
wget https://s3.amazonaws.com/rstudio-ide-build/server/bionic/amd64/$RSTUDIO
gdebi -n $RSTUDIO
# ----------------------- User and creds ----------------------------
adduser rstudio
echo "rstudio:rstudio" | chpasswd
# ----------------- Build R from source -----------------------------
apt-get -y build-dep r-base
cd /opt
mkdir R
cd R
wget https://cran.r-project.org/src/base/R-3/R-$RVERSION.tar.gz
tar zxvf R-$RVERSION.tar.gz
cd R-$RVERSION
./configure --prefix=/opt/R/R-$RVERSION --enable-R-shlib
make
make install
ln -s /opt/R/R-$RVERSION/bin/R /bin/R

# -------------------- Pre install pkgs -----------------------------
R -e 'install.packages("devtools", repos="http://cran.us.r-project.org")'
R -e 'devtools::install_github("r-lib/revdepcheck")'

# ------------------ Re initializing RStudio ------------------------
rstudio-server restart
