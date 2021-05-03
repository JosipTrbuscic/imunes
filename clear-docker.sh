sudo docker ps -a | tail -n+2 | awk '{print $1}' | xargs sudo docker stop
sudo docker ps -a | tail -n+2 | awk '{print $1}' | xargs sudo docker rm
