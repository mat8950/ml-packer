Vagrant.configure("2") do |config|
  config.vm.box = "bento/rockylinux-9"

  config.vm.hostname = "devbox"

  config.vm.network "forwarded_port", guest: 8080, host: 8080
  config.vm.network "forwarded_port", guest: 8443, host: 8443
  config.vm.network "forwarded_port", guest: 2376, host: 2376

  config.ssh.forward_agent = true

  config.vm.synced_folder ".", "/vagrant"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus = 2
    vb.name = "devbox-rockylinux9"
  end

  config.vm.provision "shell", inline: <<-SHELL
    set -e

    echo "==> Mise à jour du système"
    dnf update -y
    dnf install -y dnf-plugins-core curl unzip wget gnupg2

    echo "==> Installation de Terraform"
    dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
    dnf install -y terraform

    echo "==> Installation de Packer"
    dnf install -y packer

    echo "==> Installation d'Ansible"
    dnf install -y epel-release
    dnf install -y ansible

    echo "==> Installation d'AWS CLI v2"
    ARCH=$(uname -m)
    if [ "$ARCH" = "aarch64" ]; then
      AWS_URL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
    else
      AWS_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    fi
    curl -fsSL "$AWS_URL" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install
    rm -rf /tmp/awscliv2.zip /tmp/aws

    echo "==> Installation de Docker"
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    usermod -aG docker vagrant

    echo "==> Vérification des installations"
    export PATH=$PATH:/usr/local/bin
    terraform version
    packer version
    ansible --version
    /usr/local/bin/aws --version
    docker --version

    echo "==> Configuration du PATH"
    echo 'export PATH=$PATH:/usr/local/bin' >> /etc/profile.d/local_bin.sh
    chmod +x /etc/profile.d/local_bin.sh

    echo "==> Clonage du repo ml-iac-tp"
    dnf install -y git
    sudo -u vagrant git clone https://github.com/mat8950/ml-iac-tp.git /home/vagrant/ml-iac-tp

    echo "==> Nettoyage des packages et caches"
    dnf autoremove -y
    dnf clean all
    rm -rf /var/cache/dnf

    echo "==> Nettoyage des logs"
    journalctl --vacuum-time=1d
    find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
    find /var/log -type f -name "*.log.*" -delete
    find /var/log -type f -name "*.gz" -delete

    echo "==> Nettoyage des fichiers temporaires"
    rm -rf /tmp/* /var/tmp/*

    echo "==> Provisionnement terminé avec succès"
  SHELL
end
