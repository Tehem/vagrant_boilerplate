#!/bin/bash

# config
CONTAINER_ID="banana"
VIRTUAL_DOMAIN="banana.dev"

# vm configuration
USER="devmonkey"
DB_USER="dbuser"

# git configuration
GIT_USER="devmonkey"
GIT_NAME="Cheetah TheMonkey"
GIT_EMAIL="devmonkey@banana.dev"

PROJECTS=( `cat "projects.list" `)

# projects subpaths (relative to project root dir)
PROJECT_PATH_CONFIG="/etc"
PROJECT_PATH_DUMPS="/etc"

#######################################################################

bold=`tput bold`
normal=`tput sgr0`

function system_configure() {
    
    echo "${bold}==> Configure system ...${normal}"
    echo "==> Using user" $USER

    # Mise à jour: basic packages
    sudo apt-get update
	sudo apt-get -y install whois mcrypt git
	
	system_check_user

	system_check_folders
    
    system_configure_sql
    
    system_configure_git   
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
    count=`ls -1 /setup_data/*.sql 2>/dev/null | wc -l`

    if [ $count != 0 ]
    then 
        databases=$( ls /setup_data/*.sql | sed 's/.*\///' )
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
            
            $sql ${db} < "/setup_data/$database"
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
    
    if [ -f /setup_data/.gitconfig ]; then
        echo '==> Using custom .gitconfig file...'
        sudo -u $USER cp /setup_data/.gitconfig /home/$USER/.gitconfig
    fi  
  
}


############################################################################################
function system_install() {

    echo "${bold}==> Install system ...${normal}"
    install_system_packages
	install_ansible
    initialize_ssh
}

function install_system_packages() {
    
    echo '==> Install necessary packages ...'
	sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
	sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
	sudo apt-get -y install mysql-server
	
    # Installation des paquets utiles:
    sudo apt-get -y install openssh-client openssh-server php5 libapache2-mod-php5 php5-cli php5-mysql php5-gd curl php5-curl
    
    # MySQL user creation:
    echo "${bold}==> Create DB user" $SQL_USER "...${normal}"
    echo "GRANT ALL PRIVILEGES ON *.* TO '${SQL_USER}'@'localhost' IDENTIFIED BY '${SQL_PASSWORD}' WITH GRANT OPTION;" | mysql -u root -proot	
	
    sudo a2enmod rewrite
    sudo a2enmod ssl    
}

function install_ansible () {

    echo "${bold}==> Install ansible ...${normal}"

    if [ ! -f /usr/bin/ansible ]; then
	   sudo apt-get -y install software-properties-common
	   sudo apt-add-repository -y ppa:ansible/ansible
	   sudo apt-get update
	   sudo apt-get -y install ansible	
	fi

    if [ ! -f /home/$USER/ansible_hosts ]; then
        echo '==> Creating default ~/ansible_hosts...'
        sudo -u $USER touch /home/$USER/ansible_hosts
    fi	
	
	if [ -f /setup_data/ansible_hosts ]; then
		echo '==> Using custom ansible_hosts file...'
		sudo -u $USER cp /setup_data/ansible_hosts /home/$USER/ansible_hosts
	fi	
	
    # Remove existing line from the profile file:
    sudo sed -i "/^ANSIBLE_HOSTS.*$/d" /home/$USER/.bashrc

	# Append the new line to the bahs profile:
    echo "ANSIBLE_HOSTS=~/ansible_hosts" | sudo -u $USER tee -a /home/$USER/.bashrc
}

function initialize_ssh() {

    echo "${bold}==> Configure SSH ...${normal}"

    # Copie de la clef RSA:
    if [ ! -d /home/$USER/.ssh ]; then
        echo '==> Creating folder ~/.ssh...'
        sudo -u $USER mkdir /home/$USER/.ssh
    fi
    
	if [ -f /setup_data/id_rsa ]; then
		echo '==> Copying provided private key file...'
		sudo cp /setup_data/id_rsa /home/$USER/.ssh/id_rsa
        sudo chown $USER:$USER /home/$USER/.ssh/id_rsa
		sudo -u $USER chmod 600 /home/$USER/.ssh/id_rsa
	fi
	
    if [ ! -f /home/$USER/.ssh/id_rsa ]; then
        echo "==> Creating empty private key file ${bold}you need to put a valid key in there!${normal}..."
        sudo -u $USER touch /home/$USER/.ssh/id_rsa
        sudo -u $USER chmod 600 /home/$USER/.ssh/id_rsa
    fi
}

#######################################################################

function projects_install() {

    for project in ${PROJECTS[@]}
    do
        if [[ ! $project == \#* ]] ;
        then
            project_init "$project"    
        fi
    done

    sudo service apache2 restart
    echo "${bold}==> Install done!${normal}"
}

function project_init() {
    git_name="$1"
    project=$( echo "$git_name" | sed 's/.*\/\(.*\)\.git/\1/' )

    echo "${bold}==> Installing project ${project}...${normal}"
	
	# Création des dossiers avec droits et permissions
    echo '==> Setting up directories and project paths...'
	if [ ! -d "$TM_PATH_SOURCE/$project" ]; then sudo -u $USER mkdir "$TM_PATH_SOURCE/$project"; fi
	if [ ! -d "$TM_PATH_ETC/$project" ]; then sudo -u $USER mkdir "$TM_PATH_ETC/$project"; fi
	if [ ! -d "$TM_PATH_LOG/$project" ]; then sudo -u $USER mkdir "$TM_PATH_LOG/$project"; fi
	if [ ! -d "$TM_PATH_VAR/$project" ]; then sudo -u $USER mkdir "$TM_PATH_VAR/$project"; fi
	if [ ! -d "$TM_PATH_CACHE/$project" ]; then sudo -u $USER mkdir "$TM_PATH_CACHE/$project"; fi
	
	# apache group assign
    echo '==> Setting up access rights...'
    sudo chown "$USER:www-data" "$TM_PATH_LOG/$project"
    sudo chown "$USER:www-data" "$TM_PATH_VAR/$project"
    sudo chown "$USER:www-data" "$TM_PATH_CACHE/$project"	
	
	initialize_project_sources "$1"
    initialize_project_configuration "$project"
    echo "${bold}==> Project ${project} installed to ${TM_PATH_SOURCE}/${project}!${normal}"
}

function initialize_project_sources() {
	git_name="$1"
	project=$( echo "$git_name" | sed 's/.*\/\(.*\)\.git/\1/' )
	
    echo "${bold}==> Cloning project sources from ${git_name}...${normal}"
	sudo -u $USER git clone "$git_name" "$TM_PATH_SOURCE/$project"
}

function initialize_project_configuration() {
    project="$1"
    
    echo "==> Adding host record for project virtual host ${bold}${project}.${VIRTUAL_DOMAIN}${normal}..."

    # Remove existing line from the system hosts file:
    sudo sed -i "/^.*${project}.*$/d" /etc/hosts
    
    # Append the new line to the system hosts:
    echo "127.0.0.1 ${project}.$VIRTUAL_DOMAIN" | sudo tee -a /etc/hosts
    
    # Source code fr the project:
    src="$TM_PATH_SOURCE/$project"
    
    # Read configuration from source code:
    if [ -d "$src/$PROJECT_PATH_CONFIG" ]; then
        
        echo "==> Linking project configuration files into configuration directory ${bold}${TM_PATH_ETC}/${project}${normal}..."
        ls "$src/$PROJECT_PATH_CONFIG"

        # Remove existing configuration folder:
        sudo rm -Rf "$TM_PATH_ETC/$project"
        
        # Create symbolik link for the corresponding environment:
        sudo -u $USER ln -s "$src/$PROJECT_PATH_CONFIG" "$TM_PATH_ETC/$project"
        
        # Remove existing virtualhost definition for this project:
        if [ -f "/etc/apache2/sites-enabled/${project}.conf" ]; then
            sudo rm "/etc/apache2/sites-enabled/${project}.conf"
        fi
        
        # Create the new virtualhost symbolik link
        if [ -f "$TM_PATH_ETC/$project/virtualhost.conf" ]; then
            echo "${bold}==> Setting up provided virtualhost configuration ...${normal}"
            sudo ln -s "$TM_PATH_ETC/$project/virtualhost.conf" "/etc/apache2/sites-enabled/${project}.conf"
        fi

        # we should be able to generate the virtualhost file !!!


        # Look for database dumps if any
        count=`ls -1 $src/$PROJECT_PATH_DUMPS/*.sql 2>/dev/null | wc -l`

        if [ $count != 0 ]
        then              
            # Database is required:
            databases=$( ls $src/$PROJECT_PATH_DUMPS/*.sql | sed 's/.*\///' )
            for database in $databases; do
                
                # Extract database name:
                name=$( echo $database | sed 's/\.sql//' )
                
                # Adapt database name to the environment:
                db="${name}"

                echo "${bold}==> Importing provided database dump ${db}...${normal}"
                
                # DROP then CREATE database with mininium
                # viable data:
                sql="mysql -u ${SQL_USER} -p${SQL_PASSWORD}"
                echo "DROP   DATABASE  IF EXISTS ${db}" | $sql
                echo "CREATE DATABASE ${db}" | $sql
                
                $sql ${db} < "$src/$PROJECT_PATH_DUMPS/$database"
            done
        fi
    fi
}


#######################################################################

system_configure

system_install

projects_install

# done