# Screenshots and Demo Evidence

Add evidence here after you run the lab locally. Good portfolio evidence is usually terminal output plus one VM console screenshot.

## Terminal output

Run these commands from the repo root:

```bash
mkdir -p docs/screenshots
terraform -chdir=terraform/envs/nonprod/dev plan -refresh=false -no-color | tee docs/screenshots/terraform-plan.txt
virsh list --all | tee docs/screenshots/virsh-list.txt
virsh net-list --all | tee docs/screenshots/virsh-net-list.txt
virsh pool-list --all | tee docs/screenshots/virsh-pool-list.txt
```

## VM console screenshot

If your VM has a graphical console, try libvirt's screenshot command:

```bash
virsh screenshot lab-dev-VM1 docs/screenshots/lab-dev-VM1.ppm
```

If you want PNG:

```bash
magick docs/screenshots/lab-dev-VM1.ppm docs/screenshots/lab-dev-VM1.png
```

If `virsh screenshot` does not work, open the VM with `virt-manager` and use your desktop screenshot tool. Save the image in this directory.

## SSH proof

After the VM is up and reachable:

```bash
ssh your-user@10.10.10.150 hostnamectl | tee docs/screenshots/ssh-hostnamectl.txt
```

Before committing, check that the output does not include private keys, real passwords, or tokens.
