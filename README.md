# Terraform Libvirt Lab

Dự án này là **lab hạ tầng local bằng Terraform** để tự động tạo nhiều VM KVM/libvirt trên máy cá nhân.

Nó làm được:

* Tạo storage pool cho disk VM.
* Tạo network NAT libvirt với IP tĩnh.
* Tạo VM từ Ubuntu cloud image.
* Dùng cloud-init để cấu hình hostname, user, SSH key, password, static IP.
* Bật hugepages optional cho từng VM nặng như GitLab hoặc runner.
* Có sẵn cấu trúc module Terraform rõ ràng.
* Có Ansible inventory/playbook để test kết nối sau khi tạo VM.
* Có Ansible playbook để chuẩn bị hugepages trên host trước khi apply VM.
* Có GitLab CI để check Terraform format, validate và Ansible syntax.

Không commit các file local nhạy cảm như `terraform.tfvars`, `terraform.tfstate`, `terraform.tfstate.backup`, `.terraform/`, `.terraform.d/plugin-cache/`, SSH key hoặc file output có chứa password/token.

Cách dùng ngắn gọn:

```bash
cp terraform/envs/nonprod/dev/terraform.tfvars.example terraform/envs/nonprod/dev/terraform.tfvars
```

Sửa file:

```bash
terraform/envs/nonprod/dev/terraform.tfvars
```

Điền các giá trị local như:

* user SSH
* SSH public key
* password VM
* đường dẫn private key Ansible
* đường dẫn storage pool
* đường dẫn Ubuntu cloud image
* IP/MAC nếu cần đổi
* `hugepages` nếu VM nào cần dùng hugepages

Sau đó chạy:

```bash
cd terraform/envs/nonprod/dev
terraform init
terraform validate
terraform plan
terraform apply
```

Khi VM đã lên, test bằng Ansible:

```bash
cp ansible/inventory/hosts.ini.example ansible/inventory/hosts.ini
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbook/ping.yml
```

Nếu muốn bật hugepages cho VM nặng, khai báo trong `terraform.tfvars`:

```hcl
hugepages = {
  enabled = true
}
```

Sau đó tính số hugepages cần reserve và chuẩn bị host:

```bash
bash scripts/hugepages-plan.sh \
  --tfvars terraform/envs/nonprod/dev/terraform.tfvars \
  --write ansible/inventory/hugepages.auto.json

ansible-playbook \
  -i localhost, \
  ansible/playbook/prepare-hugepages.yml \
  -e @ansible/inventory/hugepages.auto.json \
  --ask-become-pass
```

Chi tiết thêm nằm ở `docs/architecture.md`, `docs/hugepages.md`, và `docs/screenshots/README.md`.

## GitLab CI Image và Cache

Repo có custom CI image tại `ci/Dockerfile`. Image này bake sẵn các tool nền tảng ít đổi:

* Terraform
* Ansible core
* Python/pip
* jq, curl, unzip
* libvirt-dev, pkg-config
* openssh-client

Image được build/push lên GitLab Container Registry:

```text
$CI_REGISTRY_IMAGE/iac-ci:latest
```

Với project hiện tại, image tương ứng là:

```text
10.10.10.111:5050/root/virtforge/iac-ci:latest
```

Job `validate_iac` dùng image này nên không còn `apt-get install` tool trong mỗi lần validate. GitLab Runner sẽ pull image từ Container Registry khi job chạy.

Pipeline chia trách nhiệm như sau:

* Tool hệ thống ổn định: bake vào `ci/Dockerfile`.
* Dependency theo project: cache bằng GitLab CI.
* Secret/state/runtime data: không bake vào image, không commit vào repo.

Cache GitLab CI chỉ dùng cho:

* `.terraform.d/plugin-cache/`: Terraform provider/plugin cache.
* `.cache/pip/`: pip cache.

Terraform providers, `.terraform/`, Terraform state, `terraform.tfvars`, secrets và runtime data không được bake vào image.

Job `build_iac_ci_image` chỉ chạy khi `ci/Dockerfile` thay đổi hoặc khi bấm manual. Job này login registry bằng biến GitLab CI có sẵn: `CI_REGISTRY`, `CI_REGISTRY_USER`, `CI_REGISTRY_PASSWORD`; không hardcode username/password.

CI chỉ chạy `fmt`, `validate`, và Ansible syntax-check. CI không chạy `terraform apply` vì apply cần host libvirt thật và có thể thay đổi VM/network trên máy đó.

Nếu registry nội bộ dùng HTTP tại `10.10.10.111:5050`, Docker daemon của GitLab Runner có thể cần cấu hình insecure registry cho địa chỉ này trước khi pull/push image.

Tóm lại: **repo này chứng minh bạn biết dùng Terraform để dựng lab VM local có network, cloud-init, secrets tách riêng, CI kiểm tra IaC, Ansible để verify sau khi provision, và host performance tuning bằng hugepages.**
