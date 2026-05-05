# JDI Project

Repo này dựng lab VM local bằng Terraform provider `libvirt`. Module chính nằm ở `terraform/modules/vm_stack`, environment đang dùng nằm ở `terraform/envs/nonprod/dev`.

## Không commit dữ liệu nhạy cảm

Các file sau chỉ nên nằm local trên máy chạy lab:

- `terraform.tfvars`: chứa user, password, SSH key/path và IP/MAC lab.
- `terraform.tfstate`, `terraform.tfstate.backup`: Terraform state có thể chứa cloud-init user data, bao gồm password dạng plain text.
- `.terraform/`: provider cache, máy mới chạy `terraform init` để tải lại.

File mẫu an toàn để copy là `terraform/envs/nonprod/dev/terraform.tfvars.example`.

## Yêu cầu trên máy mới

- Terraform `>= 1.3.0`.
- QEMU/KVM + libvirt đang chạy.
- User chạy Terraform có quyền dùng `qemu:///system`.
- Base cloud image tồn tại trên máy, ví dụ:

```bash
/var/lib/libvirt/images/noble-server-cloudimg-amd64.img
```

Nếu dùng path khác, sửa `base_image_path` trong `terraform.tfvars`.

## Cách chạy

Từ root repo:

```bash
cp terraform/envs/nonprod/dev/terraform.tfvars.example terraform/envs/nonprod/dev/terraform.tfvars
```

Sửa các giá trị trong `terraform/envs/nonprod/dev/terraform.tfvars`:

- `ssh_user`
- `ssh_public_key`
- `ssh_password`
- `ansible_private_key_path`
- `pool.path`
- `base_image_path`
- IP/MAC nếu mạng lab trên máy mới khác

Sau đó chạy:

```bash
cd terraform/envs/nonprod/dev
terraform init
terraform validate
terraform plan
terraform apply
```

## Ghi chú về password

Cloud-init hiện vẫn tạo password cho user để dễ login qua console/VNC. Template đang để `ssh_pwauth: false`, nên SSH password auth không được bật; SSH nên dùng public key. Nếu muốn login SSH bằng password, cần đổi rõ trong `terraform/modules/vm_stack/templates/user-data.yaml.tftpl`.
