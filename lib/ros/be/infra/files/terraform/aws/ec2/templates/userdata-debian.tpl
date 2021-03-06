#cloud-config
repo_update: true
repo_upgrade: all

packages:
  - git

runcmd:
%{ for key in ssh_public_keys ~}
  - "echo ${key} >> /home/admin/.ssh/authorized_keys"
%{ endfor ~}
  - su -c "mkdir -p ~/${project_name}/ros" - admin
  - su -c "git clone https://github.com/rails-on-services/setup.git ~/${project_name}/ros/setup" - admin
  - su -c "~/${project_name}/ros/setup/setup.sh" - admin
  - su -c "cd ~/${project_name}/ros/setup && ./backend.yml" - admin
  - su -c "cd ~/${project_name}/ros/setup && ./devops.yml" - admin
  - su -c "cd ~/${project_name}/ros/setup && ./cli.yml" - admin
