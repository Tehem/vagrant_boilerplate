#!/bin/bash

bold=`tput bold`
normal=`tput sgr0`

# Getting the project id (standard SVN one)
ENV=$( echo "$1" | sed 's,/,,g' )
if [ "$ENV" = "" ]; then
    echo "Please provide a configuration environment name, available environments: "
    ls ./config/*.conf | sed 's/.*\/\(.*\).conf/\1/'
    exit
fi

if [ ! -f ./config/$ENV.conf ]; then
    echo "No configuration file found (${bold}"./config/$ENV.conf"${normal}), available environments: "
    ls ./config/*.conf | sed 's/.*\/\(.*\).conf/\1/'
    exit
fi

#######################################################################

echo "Reading config $ENV.conf...."
source ./config/$ENV.conf

PROJECTS=( `cat "./config/projects.list" `)

#######################################################################

function system_configure() {
    
    echo "${bold}==> Configure system ...${normal}"
    echo "==> Using user" $USER

	if [ true == "$JENKINS_ENABLED" ]; then
		# Get Jenkins repository:
		wget -q -O - https://jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -
		sudo sh -c 'echo deb http://pkg.jenkins-ci.org/debian binary/ > /etc/apt/sources.list.d/jenkins.list'
	fi
	
	if [ true == "$SELENIUM_ENABLED" ]; then
		# Add Google public key to apt
		wget -q -O - "https://dl-ssl.google.com/linux/linux_signing_key.pub" | sudo apt-key add -

		# Add Google to the apt-get source list
		sudo sh -c 'echo deb http://dl.google.com/linux/chrome/deb/ stable main > /etc/apt/sources.list.d/google-chrome-stable.list'
	fi
	
    if [ true == "$MONGODB_ENABLED" ]; then
        # http://docs.mongodb.org/manual/tutorial/install-mongodb-on-ubuntu/
        sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
        echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list
    fi

    if [ true == "$ANSIBLE_ENABLED" ]; then
        sudo apt-add-repository -y ppa:ansible/ansible
    fi

    # Mise à jour: basic packages
    sudo apt-get update
	sudo apt-get -y install whois mcrypt unzip

    if [ true == "$GIT_ENABLED" ]; then
        sudo apt-get -y install git
	fi

    if [ true == "$SVN_ENABLED" ]; then
        sudo apt-get -y install subversion
    fi

	system_check_user

	system_check_folders
    
    system_configure_sql
    
    if [ true == "$GIT_ENABLED" ]; then
        system_configure_git
    fi

}

function system_check_user() {

	getent passwd $USER  > /dev/null
	
	if [ $? -ne 0 ]; then
		echo "${bold}==> Create user" $USER "and granting sudo privileges...${normal}"
		PASS=$( mkpasswd $USER )
		sudo useradd -d /home/$USER -m -G admin,sudo,vagrant,staff --password $PASS -s /bin/bash $USER
		sudo chown "$USER" /home/$USER
	fi
}

function system_check_folders() {
    
    echo "${bold}==> Checking directory structure ...${normal}"
    TM_PATH_SOURCE="/usr/local/devel/$CONTAINER_ID"
    TM_PATH_ETC="/usr/local/etc/devel/$CONTAINER_ID"
    TM_PATH_LOG="/var/log/devel/$CONTAINER_ID"

    TM_PATH_VAR="/var/local/$CONTAINER_ID"
    TM_PATH_CACHE="/var/cache/$CONTAINER_ID"

    if [ ! -d "/usr/local/etc/devel/" ]; then
        sudo mkdir "/usr/local/etc/devel/";
        sudo chown "$USER" "/usr/local/etc/devel/"
    fi

    # clean / create necessary folders
    system_clean_folders
    system_create_folders
}

function system_clean_folders() {
    
    if [ -d "$TM_PATH_VAR" ]; then sudo rm -Rf "$TM_PATH_VAR"; fi
    if [ -d "$TM_PATH_LOG" ]; then sudo rm -Rf "$TM_PATH_LOG"; fi
    if [ -d "$TM_PATH_ETC" ]; then sudo rm -Rf "$TM_PATH_ETC"; fi
    if [ -d "$TM_PATH_CACHE" ]; then sudo rm -Rf "$TM_PATH_CACHE"; fi
    if [ -d "$TM_PATH_SOURCE" ]; then sudo rm -Rf "$TM_PATH_SOURCE"; fi
}

function system_create_folders() {
    
    if [ ! -d "$TM_PATH_SOURCE" ]; then
        sudo mkdir "$TM_PATH_SOURCE";
        sudo chown "$USER" "$TM_PATH_SOURCE"
    fi
    if [ ! -d "$TM_PATH_ETC" ]; then
        sudo mkdir "$TM_PATH_ETC";
        sudo chown "$USER" "$TM_PATH_ETC"
    fi
    if [ ! -d "$TM_PATH_LOG" ]; then
        sudo mkdir "$TM_PATH_LOG";
        sudo chown "$USER" "$TM_PATH_LOG"
    fi
    if [ ! -d "$TM_PATH_CACHE" ]; then
        sudo mkdir "$TM_PATH_CACHE";
        sudo chown "$USER" "$TM_PATH_CACHE"
    fi
    if [ ! -d "$TM_PATH_VAR" ]; then
        sudo mkdir "$TM_PATH_VAR";
        sudo chown "$USER" "$TM_PATH_VAR"
    fi
}

function system_configure_sql() {

    echo "${bold}==> Setup SQL environment...${normal}"
    echo "==> Using DB user" $DB_USER

    SQL_USER=$DB_USER
    SQL_PASSWORD=$DB_USER
    sql="mysql -u ${SQL_USER} -p${SQL_PASSWORD}"

    # Look for database dumps if any
    count=`ls -1 ${SHARED_SETUP_MOUNT}/*.sql 2>/dev/null | wc -l`

    if [ $count != 0 ]
    then 
        databases=$( ls $SHARED_SETUP_MOUNT/*.sql | sed 's/.*\///' )
        for database in $databases; do
            
            # Extract database name:
            name=$( echo $database | sed 's/\.sql//' )
            
            # Adapt database name to the environment:
            db="${name}"
            echo "${bold}==> Importing database ${name}...${normal}"
            
            # DROP then CREATE database with mininium
            # viable data:
            echo "DROP   DATABASE  IF EXISTS ${db}" | $sql
            echo "CREATE DATABASE ${db}" | $sql
            
            $sql ${db} < "$SHARED_SETUP_MOUNT/$database"
        done
    fi  

}

function system_configure_git() {
    
    echo "${bold}==> Setup GIT environment...${normal}"
    echo "==> Using git user" $GIT_USER

    if [ ! -f /home/$USER/.gitconfig ]; then
        echo '==> Creating default ~/.gitconfig'
        sudo -u $USER touch /home/$USER/.gitconfig
    
        # Default config
        echo -e "[user]\n\tname = $GIT_NAME\n\temail = $GIT_EMAIL" | sudo -u $USER tee -a /home/$USER/.gitconfig          
    fi  
    
    if [ -f $SHARED_SETUP_MOUNT/.gitconfig ]; then
        echo '==> Using custom .gitconfig file...'
        sudo -u $USER cp $SHARED_SETUP_MOUNT/.gitconfig /home/$USER/.gitconfig
    fi  
  
}


############################################################################################
function system_install() {

    echo "${bold}==> Install system ...${normal}"
    install_system_packages
    initialize_ssh
	
	if [ true == "$ANSIBLE_ENABLED" ]; then
        install_ansible
    fi
    
    if [ true == "$PHABRICATOR_TOOLS_ENABLED" ]; then
        install_phabricator_tools
    fi

    if [ true == "$JENKINS_ENABLED" ]; then
        install_jenkins
    fi		
}

function install_system_packages() {
    
    echo '==> Install necessary packages ...'
	sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
	sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
	sudo apt-get -y install mysql-server
	
    # Installation des paquets utiles:
    sudo apt-get -y install openssh-client openssh-server php5 libapache2-mod-php5 php5-cli php5-mysql php5-gd curl php5-curl puppet
    
	# other packages
    if [ true == "$NODE_ENABLED" ]; then
        sudo apt-get -y install nodejs supervisor npm
    fi    

    if [ true == "$MONGODB_ENABLED" ]; then
        sudo apt-get -y install mongodb-org
    fi

	if [ true == "$MOCHA_ENABLED" ] && [ true == "$NODE_ENABLED" ]; then
	    # For Public APIs testing:
		sudo npm install -g mocha
		
		# Required by mocha to execute correctly:
		sudo ln -s /usr/bin/nodejs /usr/bin/node
	fi
	
	if [ true == "$SELENIUM_ENABLED" ]; then
	
		echo "${bold}==> Install Selenium ...${normal}"
	
		# --- Ruby Gem installation
		sudo apt-get -y install xvfb # For Selenium testing
		sudo apt-get -y install google-chrome-stable
		sudo apt-get -y install openjdk-7-jre
		sudo apt-get -y install ruby
		sudo apt-get -y install ruby-bundler
		sudo gem install rspec
		
		# Headless Selenium:
		# REF: http://www.chrisle.me/2013/08/running-headless-selenium-with-chrome/
		
		# Not validated:
		sudo npm install -g selenium-webdriver
		sudo apt-get -y install dbus-x11
		sudo apt-get -y install firefox	
		
		# Selenium chrome install:
		# REF: http://www.chrisle.me/2013/08/running-headless-selenium-with-chrome/
		wget --directory-prefix=/tmp/ http://chromedriver.storage.googleapis.com/2.10/chromedriver_linux64.zip
		unzip /tmp/chromedriver_linux64.zip
		sudo mv /tmp/chromedriver /usr/local/bin/
		
		# Get the standalone Selenium:
		wget --directory-prefix=/tmp/ https://selenium.googlecode.com/files/selenium-server-standalone-2.35.0.jar
		sudo mv /tmp/selenium-server-standalone-2.35.0.jar /usr/local/bin		
	fi
	
    # Composer installation:
    curl -sS https://getcomposer.org/installer | php
    sudo mv composer.phar /usr/local/bin/composer
	
    # MySQL user creation:
    echo "${bold}==> Create DB user" $SQL_USER "...${normal}"
    echo "GRANT ALL PRIVILEGES ON *.* TO '${SQL_USER}'@'localhost' IDENTIFIED BY '${SQL_PASSWORD}' WITH GRANT OPTION;" | mysql -u root -proot	
	
    sudo a2enmod rewrite
    sudo a2enmod ssl    
}

function initialize_ssh() {

    echo "${bold}==> Configure SSH ...${normal}"

    # Copie de la clef RSA:
    if [ ! -d /home/$USER/.ssh ]; then
        echo '==> Creating folder ~/.ssh...'
        sudo -u $USER mkdir /home/$USER/.ssh
    fi
    
	if [ -f $SHARED_SETUP_MOUNT/id_rsa ]; then
		echo '==> Copying provided private key file...'
		sudo cp $SHARED_SETUP_MOUNT/id_rsa /home/$USER/.ssh/id_rsa
        sudo chown $USER:$USER /home/$USER/.ssh/id_rsa
		sudo -u $USER chmod 600 /home/$USER/.ssh/id_rsa
	fi
	
    if [ ! -f /home/$USER/.ssh/id_rsa ]; then
        echo "==> Creating empty private key file ${bold}you need to put a valid key in there!${normal}..."
        sudo -u $USER touch /home/$USER/.ssh/id_rsa
        sudo -u $USER chmod 600 /home/$USER/.ssh/id_rsa
    fi
}

function install_ansible () {

    echo "${bold}==> Install ansible ...${normal}"

    if [ ! -f /usr/bin/ansible ]; then
	   sudo apt-get -y install software-properties-common ansible	
	fi

    if [ ! -f /home/$USER/ansible_hosts ]; then
        echo '==> Creating default ~/ansible_hosts...'
        sudo -u $USER touch /home/$USER/ansible_hosts
    fi	
	
	if [ -f $SHARED_SETUP_MOUNT/ansible_hosts ]; then
		echo '==> Using custom ansible_hosts file...'
		sudo -u $USER cp $SHARED_SETUP_MOUNT/ansible_hosts /home/$USER/ansible_hosts
	fi	
	
    # Remove existing line from the profile file:
    sudo sed -i "/^ANSIBLE_HOSTS.*$/d" /home/$USER/.bashrc

	# Append the new line to the bahs profile:
    echo "ANSIBLE_HOSTS=~/ansible_hosts" | sudo -u $USER tee -a /home/$USER/.bashrc
}

function install_phabricator_tools {

    echo "${bold}==> Install Phabricator tools ...${normal}"

    if [ ! -d /home/$USER/arc_tools ]; then
        echo '==> Creating folder ~/arc_tools...'
        sudo -u $USER mkdir /home/$USER/arc_tools
    fi

    # Clone arcanist & associated tools
    sudo -u $USER git clone https://github.com/phacility/libphutil.git /home/$USER/arc_tools/libphutil
    sudo -u $USER git clone https://github.com/phacility/arcanist.git /home/$USER/arc_tools/arcanist

    if [ -d /home/$USER/arc_tools/arcanist ]; then

        # Remove existing line from the profile file:
        sudo sed -i "/^arc_tools.*$/d" /home/$USER/.bashrc

        # Append the new line to the bash profile:
        echo "PATH=$PATH:/home/$USER/arc_tools/arcanist/bin/" | sudo -u $USER tee -a /home/$USER/.bashrc
    fi
}

function install_jenkins {
	echo "${bold}==> Install Jenkins ...${normal}"
	if [ ! -d /var/lib/jenkins ]; then
		
		sudo apt-get -y install jenkins
		        
        # Jenkins URL export:
        JENKINS_URL="http://localhost:8080"
        
        # Waiting the Jenkins to start:
        while [ ! -f "/tmp/jenkins-cli.jar" ]; do
            sleep 5
            
            # Get the Jenkins CLI jar file:
            sudo wget "${JENKINS_URL}/jnlpJars/jenkins-cli.jar" 2> /dev/null
            
        done
        
        # Move the jar file to the Jenkins directory:
        sudo mv "/tmp/jenkins-cli.jar" "/var/lib/jenkins/"

        # Execute commands for the installation:
        jenkins="java -jar /var/lib/jenkins/jenkins-cli.jar -s ${JENKINS_URL}"
        
        # Copy default Jenkins config.xml to enable anonymous user to
        # perform system configuration update
        #
        # TODO: place this file in a release management project.
        if [ -f "$SHARED_SETUP_MOUNT/config/jenkins/jenkins.xml" ]; then
            sudo cp "$SHARED_SETUP_MOUNT/config/jenkins/jenkins.xml" /var/lib/jenkins/config.xml
        fi
        
        # Jenkins finishing configuring:
        if [ -f "$SHARED_SETUP_MOUNT/config/jenkins/jenkins.xml" ]; then
            sudo cp "$SHARED_SETUP_MOUNT/config/jenkins/jenkins.security.QueueItemAuthenticatorConfiguration.xml" /var/lib/jenkins/jenkins.security.QueueItemAuthenticatorConfiguration.xml
        fi
        
        sudo chown jenkins /var/lib/jenkins/config.xml
        sudo chown jenkins /var/lib/jenkins/jenkins.security.QueueItemAuthenticatorConfiguration.xml
    
		# install build template
		curl https://raw.github.com/sebastianbergmann/php-jenkins-template/master/config.xml | $jenkins create-job php-template

        version=$( $jenkins version )
		echo "${bold}==> Jenkins $version ${normal}"
        
        jenkins_safe_restart
        
        install_system_packages_jenkins_plugins		
		
	fi
}

function install_jenkins_plugins {

    # Initialize Jenkins available plugins list:
    # REF: https://github.com/fnichol/chef-jenkins/issues/9
    if [ ! -d "/var/lib/jenkins/updates" ]; then
        sudo mkdir "/var/lib/jenkins/updates"
    fi
    
    if [ ! -f "/var/lib/jenkins/updates/default.json" ]; then
        wget http://updates.jenkins-ci.org/update-center.json -qO- | sed '1d;$d' > /tmp/default.json
        sudo cp /tmp/default.json "/var/lib/jenkins/updates/default.json"
        sudo chown -R jenkins "/var/lib/jenkins/updates"
    fi

    # Plugins installation stack!
    # Execute commands for the installation:
    jenkins="java -jar /var/lib/jenkins/jenkins-cli.jar -s http://localhost:8080"
    
    # List of plugins
	plugins="translation antisamy-markup-formatter cvs git-chooser-alternative jshint-checkstyle violation-columns plot external-monitor-job git-client analysis-collector maven-plugin htmlpublisher matrix-auth credentials scm-api measurement-plots ldap junit ssh-credentials pmd javadoc php cloverphp violations greenballs mapdb-api pam-auth git matrix-project ant xunit ssh-slaves subversion checkstyle analysis-core dry phing jdepend mailer windows-slaves crap4j openid openid4java"

    # Install required plugins:
    $jenkins install-plugin ${plugins}
    
    # Jenkins plugins update:
    # REF: http://stackoverflow.com/questions/7709993/how-can-i-update-jenkins-plugins-from-the-terminal
    UPDATE_LIST=$( $jenkins list-plugins | grep -e '(' | sed 's/ .*$//' );
    
    if [ ! -z "${UPDATE_LIST}" ]; then
        $jenkins install-plugin ${UPDATE_LIST};
    fi
    
    # Safe restart of Jenkins)
    jenkins_safe_restart
}

#######################################################################

function jenkins_safe_restart() {
    
    # Get the Jenkins Session ID:
	JENKINS_URL="http://localhost:8080"
	jenkins="java -jar /var/lib/jenkins/jenkins-cli.jar -s ${JENKINS_URL}"
    session_id=$( $jenkins session-id )
    
    $jenkins safe-restart
    
    v=""
    while [[ ( "$session_id" == "$v" ) || ( "" == "$v" ) ]]; do
        
        sleep 2
        
        v=$( $jenkins session-id 2> /dev/null )
        
    done
}

#######################################################################

system_configure
system_install

# done