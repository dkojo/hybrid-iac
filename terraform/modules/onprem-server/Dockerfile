# A Rocky Linux 9 "server": systemd as PID 1, SSH, sudo and Python, and nothing else.
# Ansible does all the real configuration, exactly as it does on the AWS server.
FROM rockylinux/rockylinux:9-ubi-init
RUN dnf install -y openssh-server sudo python3 && dnf clean all \
 && ssh-keygen -A \
 && useradd --create-home admin \
 && echo "admin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/admin && chmod 440 /etc/sudoers.d/admin \
 && install -d -m 700 -o admin -g admin /home/admin/.ssh \
 && systemctl enable sshd
EXPOSE 22 80
CMD ["/usr/sbin/init"]
