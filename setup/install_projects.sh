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

function system_check() {
    
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
    system_create_folders
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
    
    if [ true == "$NODE_ENABLED" ]; then
        sudo service supervisor restart
    fi

    echo "${bold}==> Install done!${normal}"
}

function project_init() {

    project_path="$1"
    project_type=$( echo "$project_path" | sed -r 's/(^git|^svn).*/\1/' )

    if [ 'git' == $project_type ] && [ true == "$GIT_ENABLED" ]; then
        project=$( echo "$project_path" | sed 's/.*\/\(.*\)\.git/\1/' )
        initialize_project_directories "$project"
        initialize_project_sources_git "$project_path"

    elif [ 'svn' == $project_type ] && [ true == "$SVN_ENABLED" ]; then
        project=$( echo "$project_path" |  sed 's/.*\/\(.*\)/\1/' )
        initialize_project_directories "$project"
        initialize_project_sources_svn "$project_path"
    fi    

    initialize_project_configuration "$project"
    echo "${bold}==> Project ${project} installed to ${TM_PATH_SOURCE}/${project}!${normal}"
}

function initialize_project_directories() {

    project="$1"

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
}

function initialize_project_sources_git() {
    project_path="$1"
    project=$( echo "$project_path" | sed 's/.*\/\(.*\)\.git/\1/' )
    echo "${bold}==> Cloning project sources from ${project_path}...${normal}"
    sudo -u $USER git clone "$project_path" "$TM_PATH_SOURCE/$project"
}

function initialize_project_sources_svn() {
    project_path="$1"
    project=$( echo "$project_path" |  sed 's/.*\/\(.*\)/\1/' )
    echo "${bold}==> Checkout project sources from ${project_path}...${normal}"
    sudo -u $USER svn checkout "$project_path" "$TM_PATH_SOURCE/$project"
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

        # we should be able to generate the virtualhost file !

        # Remove existing supervisor configuration file:
        if [ -f "/etc/supervisor/conf.d/${project}.conf" ]; then
            sudo rm "/etc/supervisor/conf.d/${project}.conf"
        fi
        
        # Create the new supervisor symbolik link
        if [ -f "$TM_PATH_ETC/$project/supervisor.conf" ]; then
            echo "${bold}==> Setting up provided supervisor configuration ...${normal}"
            sudo ln -s "$TM_PATH_ETC/$project/supervisor.conf" "/etc/supervisor/conf.d/${project}.conf"
        fi        

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
system_check
projects_install

# done