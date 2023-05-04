# IMM Toolkit Setup Instructions

## Updates/News

05-04-2023
* Initial Release

## Setup NGINX

Install NGINX and NetTools

```bash
sudo apt install net-tools
sudo apt install nginx
```
Configure Security Settings for nginx.

```bash
vim /etc/nginx/nginx/nginx.conf
```

* Copy the contents of the nginx.conf file

Generate the Certificate and Private Key

```bash
cd /etc/nginx
mkdir ssl
cd ssl
openssl req -new -newkey rsa:2048 -days 1095 -nodes -x509 -keyout nginx.key -out nginx.crt
chown www-data:www-data nginx.key
chown www-data:www-data nginx.crt
chmod 400 nginx.crt
chmod 400 nginx.key
```

Setup default site for File Services over HTTPS

```bash
cd /var/www/
mkdir upload
cd upload/
touch test.txt
cd /etc/nginx/sites-enabled
vim default
```

* Copy the contents of nginx-sites-defualt into the above file

```bash
systemctl restart nginx
systemctl status nginx.service
netstat -tulpn
```

## Setup NTP

* Install NTP

```bash
sudo apt install ntp
```

## Setup  OVF Customization Script

```bash
vim /usr/local/bin/ovf_network_config.sh
vim /etc/systemd/system/ovf-network-config.service
```

* Copy the contents of ovf_network_config.sh
* Copy the contents of ovf-network-config.service
* Change the Permissions on the Files

```bash
chmod 744 /usr/local/bin/ovf_network_config.sh
chmod 664 /etc/systemd/system/ovf-network-config.service
systemctl daemon-reload
systemctl enable ovf-network-config.service
```

# Install Python and Powershell Modules

```bash
sudo apt install python3-pip
sudo snap install powershell
cd ~
mkdir Downloads
mkdir github
cd github/
git clone https://github.com/scotttyso/intersight_iac
sudo ln -s /home/imm-toolkit/github/intersight_iac/ezci.py /usr/bin/ezimm.py
sudo ln -s /home/imm-toolkit/github/intersight_iac/ezci.py /usr/bin/ezci.py
cd intersight_iac/
sudo pip install -r requirements.txt
```

