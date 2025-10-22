# Test the component inside a docker

```bash
docker run -it --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
ubuntu:24.04 bash
```

After inside run:

```bash
apt update && apt install -y curl sudo vim

# Create user 'user' with home directory and bash shell
useradd -m -s /bin/bash user

# Add user to sudo group
usermod -aG sudo user

# Verify the setup
id user
grep '^sudo:' /etc/group
echo 'user ALL=(ALL) NOPASSWD:ALL' | sudo EDITOR='tee -a' visudo
```

Now, test the commands.

```bash
su - user
```