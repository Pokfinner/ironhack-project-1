# Ansible Deployment

This guide covers how to use Ansible to install Docker on the EC2 instances and deploy the application containers. The frontend instance is reached directly, and the backend and database instances are reached through it using SSH `ProxyJump`.

## Prerequisites

- Ansible installed on your local machine
- The EC2 key pair (`.pem` file) on your local machine, with restricted permissions:

  chmod 400 /path/to/key.pem

- Port 22 open from your IP to the frontend instance, and from the frontend instance to the backend and database instances (security groups)

## Step 1: Update the SSH config

Edit `~/.ssh/config` so Ansible can reach the private instances through the frontend instance (the jump host).

```
Host frontend
    HostName <FRONTEND_PUBLIC_IP_OR_DNS>
    User ec2-user
    IdentityFile /path/to/key.pem

Host backend
    HostName <BACKEND_PRIVATE_IP>
    User ec2-user
    ProxyJump frontend
    IdentityFile /path/to/key.pem

Host database
    HostName <DATABASE_PRIVATE_IP>
    User ec2-user
    ProxyJump frontend
    IdentityFile /path/to/key.pem
```

Replace the placeholders with your real IP addresses or DNS name and the path to your key file.

Test that each host is reachable before running Ansible:

```bash
ssh frontend
ssh backend
ssh database
```

## Step 2: Update the inventory

Edit `inventory.ini` as follows:

```ini
[frontend]
frontend-instance-1

[backend]
backend-instance-1

[db]
db-instance-1
```

**Important:** Ansible connects using the names listed in the inventory, so each name must match a `Host` entry in `~/.ssh/config` (or have `ansible_host` set in the inventory). If the names differ, Ansible fails to connect.

Check the connection to all hosts:

```bash
ansible -i inventory.ini all -m ping
```

## Step 3: Install Docker

Install Docker on the instances first, using `docker_playbook.yml`:

```bash
ansible-playbook -i inventory.ini docker_playbook.yml
```

## Step 4: Deploy the voting and result application

Pull the images from Docker Hub and run the containers on the EC2 instances:

```bash
ansible-playbook -i inventory.ini deploy_vote.yml deploy_result.yml

```

## Step 5: Deploy the redis and and worker application and database 
Pull the images from Docker Hub and run the containers on the EC2 instances:

```bash
ansible-playbook -i inventory.ini deploy_redis_worker.yml deploy_database.yml

```
## Verify the Deployment

Verify that the containers are running:

```bash
docker ps

```

Review container logs if necessary:

```bash
docker logs <container-name>

```
## Run order

1. Update `~/.ssh/config` (ProxyJump)
2. Update `inventory.ini`
3. `docker_playbook.yml` (install Docker)
4. `deploy_vote.yml deploy_result.yml deploy_redis_worker.yml deploy_database.yml` (pull images and run containers)

## Troubleshooting

- **Connection timed out:** check the security group rules for port 22 and the IP addresses in `~/.ssh/config`.
- **Permission denied (publickey):** check the key path, the key file permissions, and that the user is `ec2-user` for Amazon Linux.
- **Could not resolve hostname:** the inventory name doesn't match any `Host` entry in `~/.ssh/config`.