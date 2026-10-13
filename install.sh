#!/bin/bash
sudo touch /tmp/startinguserdata
sudo apt update
sudo apt upgrade -y
sudo apt install apache2 -y
sudo systemctl start apache2
sudo systemctl enable apache2
echo "Apache deployed via terraform" | sudo tee /var/www/html/index.html
sudo touch /tmp/completeduserdata
