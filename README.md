Vagrant boilerplate - web development VM setup
==============================================

This project setup a web development virtual machine using vagrant.

About the example project
-------------------------

Scripts are configured by default to work out-of-the-box with an example dummy project named [vagrant_boilerplate_example](https://github.com/Tehem/vagrant_boilerplate_example). A working private key is provided (passphrase is 'banana'). The final url to use to check the working project is : http://vagrant_boilerplate_example.banana.dev:8080


Installation
------------

1. You need to download and install [Virtualbox](https://www.virtualbox.org/wiki/Downloads) and [Vagrant](https://www.vagrantup.com/downloads.html).

2. Clone the project to your development machine which is to be the host of the development VM: run `git clone https://github.com/Tehem/vagrant_boilerplate.git`

3. Edit the `projects.list` file in setup directory, to add your project git paths.

4. Optionally edit the [`Vagrantfile`](https://docs.vagrantup.com/v2/vagrantfile/index.html) to change settings like the box you want or other vagrant options.
By default your VM will run a [Ubuntu Server 14.04 LTS (Trusty Tahr)](https://vagrantcloud.com/ubuntu/boxes/trusty64) without gui, and will be accessible through port 8080 of the host machine.

5. Optionally edit `install.sh` in setup directory, especially to setup various VM settings :
  - `CONTAINER_ID`: name of the container used for all your project and/or specific directories. Can be the name of your company of website.
  - `VIRTUAL_DOMAIN`: a virtual domain name to be created for your web projects. You will access them with urls like <project_name>.<virtual_domain> in your browser. You need to edit your host machine host file (*nix : `/etc/hosts`, Windows: `C:/Windows/System32/drivers/etc/hosts`) to add an entry for your VM like: `127.0.0.1 <your virtual domain name>`.
  - `USER`: user that will be created in the virtual machine. Usually the unix account user name of the developer.
  - `DB_USER`: a default DB user name for your web application. He will have access to your project databases and should be used in your projects configurations.
  - `GIT_USER`, `GIT_NAME`, `GIT_EMAIL`: default global git values to set up.

6. Optionally edit `ansible_hosts` in setup directory to configure your [Ansible](http://www.ansible.com/home) [inventory](http://docs.ansible.com/intro_inventory.html)
7. Optionally add an `id_rsa` file to setup your VM box user with a private key for SSH operations.
8. Optionally add `.sql` files for them to be automatically integrated in the host machine mysql server (one file per database).

Usage
-----

- Run `vagrant up` to start the VM on your host machine.
- Run `vagrant ssh` to SSH to your VM.
- Navigate to setup directory: `cd /setup_data`
- Run the install script: `./install.sh`
- Answear any prompt coming (ssh hosts acknowledgements, ssh key passphrase, etc.)
- Your machine is ready, you should see a message `Install done!`
- You can point your browser to your virtual domain name (default http://vagrant_boilerplate_example.banana.dev:8080) to see your project live (do not forget to use the port you specified in Vagrantfile if different from default 80)

Contributing
------------

All code contributions must go through a pull request before being merged. This is to ensure proper review of all the code.
Fork the project, create a feature branch, and send me a pull request. All contributions are welcome!

If you would like to help take a look at the [list of issues](http://github.com/Tehem/vagrant_boilerplate/issues).