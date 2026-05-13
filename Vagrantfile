# Lecture des credentials locaux (credentials.sh)
aws_creds = {}
creds_file = File.join(File.dirname(__FILE__), "credentials.sh")
if File.exist?(creds_file)
  File.readlines(creds_file).each do |line|
    if line =~ /export\s+(\w+)="(.+)"/
      aws_creds[$1] = $2
    end
  end
end

Vagrant.configure("2") do |config|
  config.vm.box = "bento/rockylinux-9"

  config.vm.hostname = "devbox"

  config.vm.network "forwarded_port", guest: 8080, host: 8080
  config.vm.network "forwarded_port", guest: 8443, host: 8443
  config.vm.network "forwarded_port", guest: 2376, host: 2376

  config.ssh.forward_agent = true

  config.vm.synced_folder ".", "/vagrant"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "4096"
    vb.cpus = 4
    vb.name = "devbox-rockylinux9"
  end

  config.vm.provision "shell", env: aws_creds, inline: <<-SHELL
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

    echo "==> Configuration des credentials AWS"
    if [ -n "$AWS_ACCESS_KEY_ID" ]; then
      sudo -u vagrant /usr/local/bin/aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
      sudo -u vagrant /usr/local/bin/aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
      sudo -u vagrant /usr/local/bin/aws configure set default.region "$AWS_DEFAULT_REGION"
      [ -n "$AWS_SESSION_TOKEN" ] && sudo -u vagrant /usr/local/bin/aws configure set aws_session_token "$AWS_SESSION_TOKEN"
      # Injection dans le profil pour les sessions suivantes
      echo "export AWS_ACCESS_KEY_ID=\"$AWS_ACCESS_KEY_ID\""         >> /home/vagrant/.bashrc
      echo "export AWS_SECRET_ACCESS_KEY=\"$AWS_SECRET_ACCESS_KEY\"" >> /home/vagrant/.bashrc
      echo "export AWS_DEFAULT_REGION=\"$AWS_DEFAULT_REGION\""       >> /home/vagrant/.bashrc
      echo "export TF_VAR_db_password=\"$TF_VAR_db_password\""       >> /home/vagrant/.bashrc
      [ -n "$AWS_SESSION_TOKEN" ] && echo "export AWS_SESSION_TOKEN=\"$AWS_SESSION_TOKEN\"" >> /home/vagrant/.bashrc
      echo "==> Credentials AWS configurés"
    else
      echo "==> Aucun credentials.sh trouvé, configuration AWS ignorée"
    fi

    echo "==> Clonage des repos"
    dnf install -y git
    sudo -u vagrant git clone https://github.com/mat8950/ml-iac-tp.git /home/vagrant/ml-iac-tp
    sudo -u vagrant git clone https://github.com/mat8950/ml-packer.git /home/vagrant/ml-packer

    echo "==> Installation du script de déploiement"
    cp /vagrant/deploy.sh /home/vagrant/deploy.sh
    chmod +x /home/vagrant/deploy.sh
    chown vagrant:vagrant /home/vagrant/deploy.sh

    echo "==> Nettoyage des packages et caches"
    dnf autoremove -y
    dnf clean all
    rm -rf /var/cache/dnf

    echo "==> Nettoyage des logs"
    journalctl --vacuum-time=1d
    find /var/log -type f -name "*.log" -exec truncate -s 0 {} \\;
    find /var/log -type f -name "*.log.*" -delete
    find /var/log -type f -name "*.gz" -delete

    echo "==> Nettoyage des fichiers temporaires"
    rm -rf /tmp/* /var/tmp/*

    echo "==> Provisionnement terminé avec succès"
  SHELL
end
